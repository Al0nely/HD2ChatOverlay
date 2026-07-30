#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/glossary_scraper.py - HD2 术语库采集脚本（免爬虫优先）

术语源（按优先级）：
  1. helldivers-2/json GitHub 仓库 - 官方拆包静态数据（items/factions/planets 等）
  2. api.helldivers2.dev Community REST API - 最新游戏实体 JSON
  3. 可选 --with-wiki-zh: Fandom 英文 Wiki + zh.wikipedia 中文对照补充

抓取范围（高频战场词优先）：战术配备 / 敌人名称 / 武器装备 / 战术行为动词简写；
任务类型仅抓动词与简写。

用法:
  python tools/glossary_scraper.py --out assets/glossary.core.json
  python tools/glossary_scraper.py --with-wiki-zh --out assets/glossary.core.json
"""

import argparse
import json
import re
import sys
import urllib.request
import urllib.error
from datetime import date

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) HD2ChatOverlay-GlossaryScraper/1.0"
TIMEOUT = 15

# helldivers-2/json 仓库 raw 文件候选路径（多路径回退，应对仓库结构变更）
COMMUNITY_JSON_SOURCES = [
    # (url, category)
    ("https://raw.githubusercontent.com/helldivers-2/json/main/items/stratagems.json", "stratagem"),
    ("https://raw.githubusercontent.com/helldivers-2/json/main/items/weapons.json", "weapon"),
    ("https://raw.githubusercontent.com/helldivers-2/json/main/enemies/enemies.json", "enemy"),
    ("https://raw.githubusercontent.com/helldivers-2/json/main/factions/factions.json", "faction"),
    ("https://raw.githubusercontent.com/helldivers-2/json/main/planets/planets.json", "planet"),
]

# api.helldivers2.dev Community API 候选端点
COMMUNITY_API_SOURCES = [
    ("https://api.helldivers2.dev/api/v1/stratagems", "stratagem"),
    ("https://api.helldivers2.dev/api/v1/weapons", "weapon"),
    ("https://api.helldivers2.dev/api/v1/enemies", "enemy"),
    ("https://api.helldivers2.dev/api/v1/factions", "faction"),
]

# 高频战术行为动词/简写（任务类型仅动词/简写），中英对照内置
ACTION_VERBS = [
    ("撤离", "extract", ["撤退"]),
    ("增援", "reinforce", ["复活"]),
    ("补给", "resupply", ["补货"]),
    ("呼叫空投", "call down", ["空投"]),
    ("开怪", "aggro", ["引怪"]),
    ("防守", "defend", []),
    ("摧毁", "destroy", ["拆掉"]),
    ("上传", "upload", []),
    ("启动", "activate", ["开"]),
    ("踢人", "kick", []),
]

# 内置中文对照表（社区 JSON 通常只有英文，需映射中文）
# key 为英文小写规范化形式
BUILTIN_ZH_MAP = {
    "terminid": ("虫族", ["虫子", "虫群"]),
    "automaton": ("机器人", ["机械人", "铁皮"]),
    "illuminate": ("光能者", ["鱿鱼"]),
    "bile titan": ("泰坦", ["胆汁泰坦", "吐酸泰坦"]),
    "charger": ("强袭虫", ["冲锋虫"]),
    "hunter": ("猎杀者", []),
    "stalker": ("潜行者", []),
    "devastator": ("蹂躏者", []),
    "berserker": ("狂暴者", []),
    "annihilator tank": ("坦克", ["歼灭者坦克"]),
    "bile spewer": ("胆汁喷吐者", ["喷吐者"]),
    "brood commander": ("指挥官", ["巢穴指挥官"]),
    "spore spewer": ("孢子喷射虫", []),
    "shrieker": ("尖啸者", ["飞虫"]),
    "impaler": ("穿刺者", []),
    "hulk": ("巨型者", ["浩克"]),
    "gunship": ("炮艇", []),
    "factory strider": ("工厂步行者", ["移动工厂"]),
    "recoilless rifle": ("无后坐力步枪", ["无后座"]),
    "railgun": ("磁轨炮", []),
    "breaker": ("破裂者", []),
    "arc thrower": ("电弧发射器", ["电弧"]),
    "flamethrower": ("火焰喷射器", ["喷火器"]),
    "machine gun": ("机枪", ["MG"]),
    "autocannon": ("机炮", []),
    "spear": ("飞矛", []),
    "quasar cannon": ("类星体加农炮", ["类星体"]),
    "eagle airstrike": ("飞鹰空袭", ["空袭"]),
    "eagle cluster bomb": ("飞鹰集束炸弹", ["集束弹"]),
    "eagle napalm airstrike": ("飞鹰凝固汽油空袭", ["汽油弹"]),
    "orbital railcannon strike": ("轨道炮", ["轨道打击"]),
    "orbital precision strike": ("轨道精准打击", ["OPS"]),
    "orbital gas strike": ("轨道毒气打击", ["毒气"]),
    "orbital 380mm he barrage": ("轨道380MM高爆弹幕", ["380"]),
    "gatling sentry": ("加特林哨戒炮", ["哨戒炮"]),
    "machine gun sentry": ("机枪哨戒炮", []),
    "mortar sentry": ("迫击炮哨戒炮", ["迫击炮"]),
    "tesla tower": ("特斯拉电塔", ["电塔"]),
    "shield generator pack": ("护盾生成器背包", ["护盾包"]),
    "supply pack": ("补给背包", ["补给包"]),
    "jump pack": ("喷射背包", ["跳包"]),
    "guard dog": ("护卫犬", ["狗"]),
    "hellbomb": ("地狱火炸弹", ["地狱火"]),
    "helldiver": ("绝地潜兵", ["潜兵"]),
    "super earth": ("超级地球", []),
    "managed democracy": ("管理式民主", []),
    "sample": ("样本", ["标本"]),
    "requisition": ("申购单", ["R点"]),
    "medal": ("奖章", ["勋章"]),
    "super credits": ("超级货币", ["SC"]),
    "helldive": ("难度9", ["地狱潜兵难度", "N9"]),
    "extract": ("撤离", ["撤退"]),
    "extraction point": ("撤离点", ["撤离区"]),
    "bug nest": ("虫巢", ["虫穴"]),
    "bug breach": ("虫巢爆发", []),
    "stratagem": ("战术配备", ["战略配备"]),
}


def http_get_json(url):
    """GET JSON，失败静默返回 None"""
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            if resp.status != 200:
                return None
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def normalize_en(name):
    """规范化英文名用于对照查找"""
    name = re.sub(r"^(the|a|an)\s+", "", name.strip(), flags=re.IGNORECASE)
    name = re.sub(r"[^a-z0-9\s]", "", name.lower())
    return re.sub(r"\s+", " ", name).strip()


def extract_names(data):
    """从社区 JSON 的各种结构中提取英文名称列表（多结构回退）"""
    names = []
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                for key in ("name", "title", "displayName", "id"):
                    if key in item and isinstance(item[key], str) and item[key].strip():
                        names.append(item[key].strip())
                        break
            elif isinstance(item, str):
                names.append(item.strip())
    elif isinstance(data, dict):
        # 可能是 { "data": [...] } 或 { "items": [...] } 包装
        for key in ("data", "items", "results", "stratagems", "weapons", "enemies"):
            if key in data:
                names.extend(extract_names(data[key]))
                break
        else:
            # 顶层即 { id: {name...} } 映射
            for v in data.values():
                if isinstance(v, dict) and "name" in v:
                    names.append(str(v["name"]).strip())
    return [n for n in names if n and len(n) < 60]


def collect_from_sources(sources, label):
    """遍历源列表，返回 {category: set(en_names)}"""
    collected = {}
    for url, category in sources:
        print(f"[采集] {label} {category}: {url}")
        data = http_get_json(url)
        if data is None:
            continue
        names = extract_names(data)
        print(f"  -> 提取 {len(names)} 个名称")
        collected.setdefault(category, set()).update(names)
    return collected


def build_terms(en_by_category):
    """将英文名集合转为术语条目，优先匹配内置中文对照"""
    terms = []
    seen = set()
    for category, names in en_by_category.items():
        for en in sorted(names):
            key = normalize_en(en)
            if key in seen or not key:
                continue
            seen.add(key)
            if key in BUILTIN_ZH_MAP:
                zh, aliases = BUILTIN_ZH_MAP[key]
                terms.append({"zh": zh, "en": en, "aliases": aliases, "category": category})
            else:
                # 无中文对照时暂以英文占位（Wiki 中文对照阶段可补齐）
                terms.append({"zh": en, "en": en, "aliases": [], "category": category})
    return terms


def add_builtin_and_actions(terms):
    """确保内置高频词与战术动词全部存在"""
    existing_keys = {normalize_en(t["en"]) for t in terms}

    for key, (zh, aliases) in BUILTIN_ZH_MAP.items():
        if key not in existing_keys:
            terms.append({"zh": zh, "en": key, "aliases": aliases, "category": "term"})

    action_keys = {normalize_en(t["en"]) for t in terms if t["category"] == "action"}
    for zh, en, aliases in ACTION_VERBS:
        if normalize_en(en) not in action_keys:
            terms.append({"zh": zh, "en": en, "aliases": aliases, "category": "action"})

    # 去重（zh+en 组合）
    uniq, seen = [], set()
    for t in terms:
        k = (t["zh"], t["en"])
        if k not in seen:
            seen.add(k)
            uniq.append(t)
    return uniq


def with_wiki_zh(terms):
    """可选：从 zh.wikipedia 抓取中文对照（占位实现，按词条逐个查询成本高，
    实际仅对无中文对照的条目尝试一次，失败则保留英文占位）"""
    missing = [t for t in terms if t["zh"] == t["en"]]
    print(f"[Wiki对照] 无中文对照条目 {len(missing)} 个（逐个查询成本高，建议人工维护 BUILTIN_ZH_MAP）")
    # 保守策略：不自动批量爬取维基（避免请求风暴与封禁），仅提示。
    # 需要时可在 BUILTIN_ZH_MAP 中补充后重新运行。
    return terms


def main():
    ap = argparse.ArgumentParser(description="HD2 术语库采集（免爬虫优先）")
    ap.add_argument("--out", default="assets/glossary.core.json", help="输出路径")
    ap.add_argument("--with-wiki-zh", action="store_true", help="可选：尝试中文维基对照")
    ap.add_argument("--offline-builtin-only", action="store_true", help="仅使用内置对照表（完全离线）")
    args = ap.parse_args()

    en_by_category = {}

    if not args.offline_builtin_only:
        # 主源1: helldivers-2/json 仓库
        en_by_category.update(collect_from_sources(COMMUNITY_JSON_SOURCES, "community-json"))
        # 主源2: api.helldivers2.dev（补充）
        for cat, names in collect_from_sources(COMMUNITY_API_SOURCES, "community-api").items():
            en_by_category.setdefault(cat, set()).update(names)
    else:
        print("[模式] 完全离线，仅使用内置对照表")

    terms = build_terms(en_by_category)
    terms = add_builtin_and_actions(terms)

    if args.with_wiki_zh:
        terms = with_wiki_zh(terms)

    out = {
        "version": date.today().strftime("%Y.%m.%d"),
        "source": "helldivers-2/json + api.helldivers2.dev" + (" + wiki-zh" if args.with_wiki_zh else ""),
        "terms": terms,
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"[完成] 共 {len(terms)} 条术语 -> {args.out} (版本 {out['version']})")


if __name__ == "__main__":
    main()
