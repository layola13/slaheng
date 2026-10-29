#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
衡 · Heng —— kb 知识底座校验器（v0.1）。

实现说明：本校验器以 Python 脚本实现（数据工程工具，非引擎运行时）；
其缺口与 SLA 迁移计划记于仓根 GAPS.md 的 kb 节。工具链冒烟已确认
sa 0.1.8 / sla check 可用，本脚本不依赖 SLA 工具链。

校验项：
  1. JSON 可解析、顶层为条目数组
  2. 条目 schema：id/kind/payload/provenance/curriculum/topic 齐全；
     provenance ∈ derived | measured:<ref> | assumed | extern:<name>
  3. id 全局唯一
  4. species：独立化学式解析器重算 composition 并与条目声明逐项比对；
     id 必须等于 "formula1:<formula>@<charge>"；元素符号合法
  5. equation：所引 species id 必须存在（引用完整性）；元素守恒；
     电荷守恒；arrow ∈ {"->", "<=>"}；系数为正整数
  6. fact（原子量表）：mass_textbook 与 mass_precise 均为正数，
     且 |textbook - precise| <= 0.6（课本取整口径自洽）
用法：python3 validate_kb.py [kb根目录]   退出码 0=全过 1=有失败
报告同时写入 <kb根目录>/validation_report.txt
"""
import json, os, sys
from collections import Counter

ELEMENTS = set("""H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co Ni Cu Zn
Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd
Tb Dy Ho Er Tm Yb Lu Hf Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Ra Th Pa U""".split())


def parse_group(s, i):
    """解析 s[i:] 的一个序列，返回 (counts, next_i)；在 ) 或 ] 或串尾停下。"""
    counts = Counter()
    n = len(s)
    while i < n:
        ch = s[i]
        if ch in ")]":
            return counts, i + 1
        if ch in "([":
            sub, i = parse_group(s, i + 1)
            # 组后下标
            j = i
            while j < n and s[j].isdigit():
                j += 1
            mult = int(s[i:j]) if j > i else 1
            i = j
            for el, c in sub.items():
                counts[el] += c * mult
        elif ch.isupper():
            j = i + 1
            if j < n and s[j].islower():
                j += 1
            el = s[i:j]
            if el not in ELEMENTS:
                raise ValueError("未知元素符号: %s" % el)
            k = j
            while k < n and s[k].isdigit():
                k += 1
            cnt = int(s[j:k]) if k > j else 1
            counts[el] += cnt
            i = k
        else:
            raise ValueError("化学式解析失败于 %r（位置 %d）" % (s, i))
    return counts, i


def parse_formula(formula):
    """化学式 -> composition。支持括号/方括号嵌套与 '·' 分隔的水合段（段首可带系数）。"""
    total = Counter()
    for seg in formula.split("·"):
        mult = 1
        body = seg
        k = 0
        while k < len(seg) and seg[k].isdigit():
            k += 1
        if k > 0 and k < len(seg):
            mult = int(seg[:k])
            body = seg[k:]
        sub, used = parse_group(body, 0)
        if used != len(body):
            raise ValueError("化学式 %r 段 %r 未完全解析" % (formula, seg))
        for el, c in sub.items():
            total[el] += c * mult
    return dict(total)


def prov_ok(p):
    return p == "derived" or p == "assumed" or p.startswith("measured:") or p.startswith("extern:")


def main():
    kb_root = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..")
    data_dir = os.path.join(kb_root, "data")
    files = ["species_junior.json", "equations_junior.json", "species_senior.json",
             "equations_senior.json", "atomic_masses.json"]
    lines, fails = [], []
    def ok(msg): lines.append("PASS  " + msg)
    def bad(msg): lines.append("FAIL  " + msg); fails.append(msg)

    entries = []
    for fn in files:
        path = os.path.join(data_dir, fn)
        try:
            with open(path, encoding="utf-8") as f:
                arr = json.load(f)
            assert isinstance(arr, list)
            entries += [(fn, e) for e in arr]
            ok("%s 解析成功，%d 条" % (fn, len(arr)))
        except Exception as ex:
            bad("%s 解析失败: %s" % (fn, ex))

    # schema + id 唯一
    ids = Counter()
    for fn, e in entries:
        for key in ("id", "kind", "payload", "provenance", "curriculum", "topic"):
            if key not in e:
                bad("%s 条目 %s 缺字段 %s" % (fn, e.get("id", "?"), key))
        if not prov_ok(str(e.get("provenance", ""))):
            bad("条目 %s provenance 格式非法: %r" % (e.get("id"), e.get("provenance")))
        if e.get("curriculum") not in ("初中", "高中"):
            bad("条目 %s curriculum 非法: %r" % (e.get("id"), e.get("curriculum")))
        ids[e.get("id")] += 1
    for eid, c in ids.items():
        if c > 1:
            bad("id 重复 %d 次: %s" % (c, eid))
    if not any("重复" in f for f in fails):
        ok("全部 id 全局唯一（%d 条）" % len(entries))

    species_by_id = {}
    counts = Counter()
    for fn, e in entries:
        kind = e.get("kind")
        counts[(e.get("curriculum"), kind)] += 1
        p = e.get("payload", {})
        if kind == "species":
            species_by_id[e["id"]] = e
            try:
                calc = parse_formula(p["formula"])
            except Exception as ex:
                bad("species %s 化学式解析失败: %s" % (e["id"], ex)); continue
            decl = {k: v for k, v in p["composition"].items()}
            if calc != decl:
                bad("species %s composition 不符: 解析得 %s，声明 %s" % (e["id"], calc, decl))
            expect_id = "formula1:%s@%d" % (p["formula"], p["charge"])
            if e["id"] != expect_id:
                bad("species %s id 与 formula/charge 不一致，应为 %s" % (e["id"], expect_id))
            if not isinstance(p["charge"], int):
                bad("species %s charge 非整数" % e["id"])
        elif kind == "equation":
            pass  # 下方统一验
        elif kind == "fact":
            tb, pr = p.get("mass_textbook"), p.get("mass_precise")
            if not (isinstance(tb, (int, float)) and isinstance(pr, (int, float)) and tb > 0 and pr > 0):
                bad("fact %s 原子量字段非法" % e["id"])
            elif abs(tb - pr) > 0.6:
                bad("fact %s 课本取整值 %s 与精确值 %s 相差过大" % (e["id"], tb, pr))
        else:
            bad("条目 %s kind 非法: %r" % (e["id"], kind))
    n_species_bad = len([f for f in fails if f.startswith("species")])
    lines.append("INFO  species composition/id 验算完成，失败 %d 条" % n_species_bad)

    # 方程式：引用完整性 + 元素守恒 + 电荷守恒
    eq_total, eq_bad = 0, 0
    for fn, e in entries:
        if e.get("kind") != "equation":
            continue
        eq_total += 1
        p = e["payload"]
        if p.get("arrow") not in ("->", "<=>"):
            bad("equation %s arrow 非法: %r" % (e["id"], p.get("arrow"))); eq_bad += 1
        elem, chg = Counter(), 0
        broken = False
        for side, sign in (("lhs", 1), ("rhs", -1)):
            for ref, coef in p[side]:
                if not (isinstance(coef, int) and coef > 0):
                    bad("equation %s 系数非法: %s x %r" % (e["id"], ref, coef)); broken = True
                sp = species_by_id.get(ref)
                if sp is None:
                    bad("equation %s 引用不存在的物种: %s" % (e["id"], ref)); broken = True; continue
                for el, c in sp["payload"]["composition"].items():
                    elem[el] += sign * coef * c
                chg += sign * coef * sp["payload"]["charge"]
        if broken:
            eq_bad += 1
            continue
        resid = {el: v for el, v in elem.items() if v != 0}
        if resid:
            bad("equation %s 元素不守恒，残差 %s" % (e["id"], resid)); eq_bad += 1
        elif chg != 0:
            bad("equation %s 电荷不守恒，残差 %+d" % (e["id"], chg)); eq_bad += 1
    if eq_bad == 0:
        ok("全部 %d 条方程式：引用完整、元素守恒、电荷守恒" % eq_total)

    lines.append("INFO  条目计数（curriculum × kind）:")
    for (curr, kind) in sorted(counts):
        lines.append("INFO    %s %s: %d" % (curr, kind, counts[(curr, kind)]))
    lines.append("RESULT  %s（失败 %d 项）" % ("ALL PASS" if not fails else "FAILURES PRESENT", len(fails)))
    report = "\n".join(lines) + "\n"
    sys.stdout.write(report)
    with open(os.path.join(kb_root, "validation_report.txt"), "w", encoding="utf-8") as f:
        f.write(report)
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
