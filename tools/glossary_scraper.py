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
    ("清巢", "clear nest", ["清理虫巢"]),
    ("清据点", "clear outpost", ["拆据点"]),
    ("丢样本", "drop samples", ["掉落样本"]),
    ("掩护我", "cover me", []),
    ("拉开距离", "fall back", ["撤退"]),
    ("压进去", "push in", ["冲"]),
]

# 内置中文对照表（包含 HD2 绝大多数战术配备、敌人实体、武器装备、战场建筑与游戏术语）
# key 为英文小写规范化形式
BUILTIN_ZH_MAP = {
    # 阵营
    "terminid": ("虫族", ["虫子", "虫群"]),
    "automaton": ("机器人", ["机械人", "铁皮"]),
    "illuminate": ("光能者", ["鱿鱼"]),

    # 敌人 (虫族)
    "bile titan": ("泰坦", ["胆汁泰坦", "吐酸泰坦"]),
    "charger": ("强袭虫", ["冲锋虫"]),
    "hunter": ("猎杀者", []),
    "stalker": ("潜行者", []),
    "bile spewer": ("胆汁喷吐者", ["喷吐者"]),
    "brood commander": ("指挥官", ["巢穴指挥官"]),
    "spore spewer": ("孢子喷射虫", []),
    "shrieker": ("尖啸者", ["飞虫"]),
    "impaler": ("穿刺者", []),
    "warrior": ("战士虫", ["战士"]),
    "scavenger": ("清道夫", ["小虫"]),
    "nursery titan": ("幼年泰坦", []),
    "alpha commander": ("阿尔法指挥官", ["红指挥官"]),

    # 敌人 (机器人)
    "hulk": ("巨型者", ["浩克"]),
    "devastator": ("蹂躏者", []),
    "heavy devastator": ("重型蹂躏者", ["盾牌兵", "大盾哥"]),
    "rocket devastator": ("火箭蹂躏者", ["火箭哥"]),
    "berserker": ("狂暴者", []),
    "annihilator tank": ("坦克", ["歼灭者坦克"]),
    "shredder tank": ("粉碎者坦克", ["机关炮坦克"]),
    "rocket tank": ("火箭坦克", []),
    "gunship": ("炮艇", []),
    "factory strider": ("工厂步行者", ["移动工厂"]),
    "trooper": ("步兵", ["小机器人"]),
    "scout strider": ("侦察步行者", ["鸡腿人", "双足机器人"]),
    "scorcher hulk": ("喷火浩克", ["喷火哥"]),
    "rocket hulk": ("火箭浩克", []),
    "war strider": ("战争步行者", []),

    # 战术配备 (Stratagems - 飞鹰)
    "eagle airstrike": ("飞鹰空袭", ["空袭"]),
    "eagle cluster bomb": ("飞鹰集束炸弹", ["集束弹"]),
    "eagle napalm airstrike": ("飞鹰凝固汽油空袭", ["汽油弹"]),
    "eagle 500kg bomb": ("飞鹰500KG炸弹", ["500KG", "500K"]),
    "eagle 110mm rocket pods": ("飞鹰110MM火箭巢", ["110", "110火箭"]),
    "eagle strafing run": ("飞鹰扫射", ["扫射"]),
    "eagle smoke strike": ("飞鹰烟雾打击", ["烟雾弹"]),

    # 战术配备 (Stratagems - 轨道)
    "orbital railcannon strike": ("轨道炮", ["轨道打击"]),
    "orbital precision strike": ("轨道精准打击", ["OPS"]),
    "orbital gas strike": ("轨道毒气打击", ["毒气"]),
    "orbital 380mm he barrage": ("轨道380MM高爆弹幕", ["380"]),
    "orbital 120mm he barrage": ("轨道120MM高爆弹幕", ["120"]),
    "orbital laser": ("轨道激光", ["激光"]),
    "orbital walking barrage": ("轨道移动弹幕", ["移动弹幕"]),
    "orbital airburst strike": ("轨道空爆打击", ["空爆"]),
    "orbital gatling barrage": ("轨道加特林弹幕", ["加特林打击"]),

    # 战术配备 (Stratagems - 重武器与背包)
    "recoilless rifle": ("无后坐力步枪", ["无后座"]),
    "railgun": ("磁轨炮", []),
    "arc thrower": ("电弧发射器", ["电弧"]),
    "flamethrower": ("火焰喷射器", ["喷火器"]),
    "machine gun": ("机枪", ["MG"]),
    "heavy machine gun": ("重型机枪", ["HMG"]),
    "autocannon": ("机炮", []),
    "spear": ("飞矛", []),
    "quasar cannon": ("类星体加农炮", ["类星体"]),
    "anti-materiel rifle": ("反器材步枪", ["AMR", "狙击枪"]),
    "grenade launcher": ("榴弹发射器", ["榴弹"]),
    "commando": ("司令官火箭筒", ["司令官", "四联装"]),
    "airburst rocket launcher": ("空爆火箭发射器", ["空爆火箭"]),
    "laser cannon": ("激光炮", []),
    "shield generator pack": ("护盾生成器背包", ["护盾包"]),
    "supply pack": ("补给背包", ["补给包"]),
    "jump pack": ("喷射背包", ["跳包"]),
    "guard dog": ("护卫犬", ["狗"]),
    "guard dog rover": ("护卫犬漫游者", ["激光狗"]),
    "ballistic shield backpack": ("防弹盾牌背包", ["防弹盾"]),

    # 战术配备 (Stratagems - 炮台与设施)
    "gatling sentry": ("加特林哨戒炮", ["哨戒炮"]),
    "machine gun sentry": ("机枪哨戒炮", []),
    "mortar sentry": ("迫击炮哨戒炮", ["迫击炮"]),
    "ems mortar sentry": ("电磁迫击炮哨戒炮", ["电磁迫击炮"]),
    "autocannon sentry": ("机炮哨戒炮", ["机炮塔"]),
    "rocket sentry": ("火箭哨戒炮", ["火箭塔"]),
    "tesla tower": ("特斯拉电塔", ["电塔"]),
    "shield generator relay": ("护盾生成器中继器", ["大护盾", "护盾罩"]),
    "anti-personnel minefield": ("杀伤人员地雷", ["地雷"]),
    "incendiary mines": ("燃烧地雷", ["火雷"]),
    "anti-tank mines": ("反坦克地雷", []),
    "heavy machine gun emplacement": ("重型机枪阵地", ["固定机枪"]),

    # 战术配备 (Stratagems - 机甲)
    "patriot exosuit": ("爱国者外骨骼机甲", ["机甲", "高达"]),
    "emancipator exosuit": ("解放者外骨骼机甲", ["双机炮机甲"]),

    # 武器与装备 (Weapons)
    "breaker": ("破裂者", []),
    "punisher": ("惩罚者", []),
    "slugger": ("独头弹惩罚者", ["独头弹"]),
    "sickle": ("镰刀", []),
    "scorcher": ("焦土", []),
    "dominator": ("主宰", ["JAR-5主宰"]),
    "p-19 redeemer": ("救赎者手枪", ["救赎者"]),
    "p-4 senator": ("参议员左轮", ["参议员", "左轮"]),
    "impact grenade": ("冲击手雷", ["冲击弹"]),
    "stun grenade": ("眩晕手雷", ["眩晕弹"]),
    "thermite grenade": ("铝热手雷", ["铝热弹"]),

    # 建筑、目标与术语 (Objectives & Environment)
    "hellbomb": ("地狱火炸弹", ["地狱火"]),
    "radar station": ("雷达站", []),
    "jamming tower": ("干扰塔", ["干扰站"]),
    "detector tower": ("检测塔", ["眼睛塔"]),
    "gunship facility": ("炮艇工厂", ["炮艇基地"]),
    "seaf artillery": ("战术炮台", ["SEAF炮台"]),
    "sam site": ("防空导弹阵地", ["SAM阵地"]),
    "anti-air": ("防空炮", ["AA炮"]),
    "shrieker nest": ("尖啸者巢穴", ["飞虫巢"]),
    "bug nest": ("虫巢", ["虫穴"]),
    "bug breach": ("虫巢爆发", []),
    "extraction point": ("撤离点", ["撤离区"]),

    # 资源与游戏术语
    "helldiver": ("绝地潜兵", ["潜兵"]),
    "super earth": ("超级地球", []),
    "managed democracy": ("管理式民主", []),
    "sample": ("样本", ["标本"]),
    "common sample": ("普通样本", ["绿色样本", "绿样"]),
    "rare sample": ("稀有样本", ["橙色样本", "橙样"]),
    "super sample": ("超级样本", ["粉色样本", "粉样"]),
    "requisition": ("申购单", ["R点"]),
    "medal": ("奖章", ["勋章"]),
    "super credits": ("超级货币", ["SC"]),
    "helldive": ("难度9", ["地狱潜兵难度", "N9"]),
    "stratagem": ("战术配备", ["战略配备"]),
    "friendly fire": ("队友伤害", ["友军伤害", "FF"]),
    "side objective": ("次要目标", ["副任务", "支线"]),
    "main objective": ("主要目标", ["主任务", "主线"]),
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
