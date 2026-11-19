"""Build the NutriSafe common-food catalog from USDA FoodData Central files.

Every nutrition number and portion weight is read from the USDA data by FDC id;
this script only chooses which foods to include, what to call them, and which
search words (English / Hinglish / Hindi) find them.

Usage: python -I build_catalog.py <sr_dir> <fndds_json> <out_dir>
"""
import csv
import hashlib
import json
import re
import sys
from fractions import Fraction

sr_dir, fndds_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]

KATORI_ML, GLASS_ML, CUP_ML = 150.0, 250.0, 236.588

# (dataset, fdc_id, display name, category, search words, extra units)
# extra units: "k" = add katori (150 ml, from the cup weight), "g" = add glass (250 ml)
FOODS = [
    # ---- Breads & grains
    ("FN", 2707713, "Roti / Chapati", "Breads & grains", "roti chapati chapatti phulka रोटी चपाती फुलका", ""),
    ("FN", 2707715, "Paratha", "Breads & grains", "paratha parantha parotta पराठा", ""),
    ("FN", 2707613, "Naan", "Breads & grains", "naan nan नान", ""),
    ("FN", 2707714, "Puri", "Breads & grains", "puri poori पूरी", ""),
    ("FN", 2708408, "Rice, white, cooked", "Breads & grains", "rice chawal chaval bhaat bhat चावल भात", "k"),
    ("FN", 2708414, "Rice, brown, cooked", "Breads & grains", "brown rice chawal ब्राउन राइस", "k"),
    ("FN", 2708951, "Fried rice, vegetable", "Breads & grains", "fried rice veg फ्राइड राइस", "k"),
    ("FN", 2709077, "Pulao (rice pilaf)", "Breads & grains", "pulao pulav pilaf पुलाव", "k"),
    ("FN", 2708985, "Biryani, vegetable", "Breads & grains", "veg biryani biriyani बिरयानी", "k"),
    ("FN", 2706538, "Biryani, chicken", "Breads & grains", "chicken biryani biriyani बिरयानी", "k"),
    ("FN", 2706490, "Biryani, meat", "Breads & grains", "mutton biryani biriyani meat बिरयानी", "k"),
    ("FN", 2708347, "Dosa, plain", "Breads & grains", "dosa dosai plain डोसा", ""),
    ("FN", 2709129, "Dosa, with filling (masala dosa)", "Breads & grains", "masala dosa dosai मसाला डोसा", ""),
    ("FN", 2708346, "Idli", "Breads & grains", "idli idly इडली", ""),
    ("FN", 2709128, "Upma", "Breads & grains", "upma uppuma उपमा", "k"),
    ("FN", 2708381, "Oats porridge, made with water", "Breads & grains", "oats oatmeal porridge ओट्स", "k"),
    ("FN", 2708383, "Oats porridge, made with milk", "Breads & grains", "oats oatmeal porridge milk ओट्स", "k"),
    ("FN", 2708489, "Oats, dry", "Breads & grains", "oats raw rolled ओट्स", ""),
    ("FN", 2707598, "Bread, white", "Breads & grains", "bread white double roti pav ब्रेड", ""),
    ("FN", 2707709, "Bread, whole wheat (brown bread)", "Breads & grains", "brown bread whole wheat atta bread ब्रेड", ""),
    ("FN", 2708352, "Noodles, cooked", "Breads & grains", "noodles chowmein नूडल्स", "k"),
    ("FN", 2708453, "Corn flakes", "Breads & grains", "cornflakes corn flakes cereal कॉर्न फ्लेक्स", ""),
    # ---- Dals & legumes
    ("FN", 2707427, "Dal", "Dals & legumes", "dal daal dhal lentil दाल", "k"),
    ("FN", 2707431, "Lentil curry", "Dals & legumes", "dal curry masoor lentil curry दाल", "k"),
    ("FN", 2707430, "Sambar", "Dals & legumes", "sambar sambhar सांभर", "k"),
    ("SR", 172421, "Lentils (masoor), boiled", "Dals & legumes", "masoor lentils boiled मसूर", "k"),
    ("SR", 173757, "Chickpeas (chana), boiled", "Dals & legumes", "chana chole chhole kabuli chickpeas चना छोले", "k"),
    ("SR", 173740, "Kidney beans (rajma), boiled", "Dals & legumes", "rajma kidney beans राजमा", "k"),
    ("SR", 174257, "Green gram (moong), boiled", "Dals & legumes", "moong mung green gram मूंग", "k"),
    ("SR", 172427, "Black gram (urad), boiled", "Dals & legumes", "urad black gram उड़द", "k"),
    ("FN", 2709632, "Chana saag", "Dals & legumes", "chana saag channa चना साग", "k"),
    ("FN", 2709768, "Bean sprouts, raw", "Dals & legumes", "sprouts ankurit moong sprouts अंकुरित", "k"),
    ("SR", 172475, "Tofu, firm", "Dals & legumes", "tofu soya paneer टोफू", ""),
    # ---- Dairy
    # Paneer is left out on purpose: the USDA entry "Cheese, paneer" lists 22.5 g carbohydrate and
    # 23.3 g sugar per 100 g, which does not describe plain paneer.
    ("FN", 2705385, "Milk, whole", "Dairy", "milk doodh dudh full cream दूध", "g"),
    ("FN", 2705387, "Milk, low fat (1%)", "Dairy", "milk toned low fat doodh दूध", "g"),
    ("FN", 2705418, "Curd / Yogurt, plain, whole milk", "Dairy", "curd dahi yogurt yoghurt दही", "k"),
    ("FN", 2705419, "Curd / Yogurt, plain, low fat", "Dairy", "curd dahi yogurt low fat दही", "k"),
    ("FN", 2705393, "Buttermilk", "Dairy", "buttermilk chaas chhach chaach mattha छाछ मट्ठा", "g"),
    ("FN", 2710168, "Ghee", "Dairy", "ghee clarified butter घी", "t"),
    ("FN", 2710155, "Butter", "Dairy", "butter makhan makkhan मक्खन", "t"),
    ("FN", 2705709, "Cheese, cheddar", "Dairy", "cheese चीज़", ""),
    ("FN", 2705630, "Ice cream, vanilla", "Dairy", "ice cream icecream आइसक्रीम", ""),
    # ---- Curries & dishes
    ("FN", 2709631, "Palak paneer", "Curries & dishes", "palak paneer पालक पनीर", "k"),
    ("FN", 2710067, "Vegetable curry", "Curries & dishes", "sabzi sabji vegetable curry mixed veg सब्ज़ी सब्जी", "k"),
    ("FN", 2706437, "Chicken curry", "Curries & dishes", "chicken curry murgh चिकन करी", "k"),
    ("FN", 2706460, "Fish curry", "Curries & dishes", "fish curry machli machhi मछली करी", "k"),
    ("FN", 2706413, "Mutton with gravy", "Curries & dishes", "mutton gosht lamb curry मटन", "k"),
    # ---- Eggs, meat & fish
    ("SR", 173424, "Egg, boiled", "Eggs, meat & fish", "egg anda boiled अंडा", ""),
    ("SR", 172185, "Egg omelette", "Eggs, meat & fish", "omelette omelet egg anda आमलेट", ""),
    ("SR", 172187, "Egg, scrambled", "Eggs, meat & fish", "egg bhurji scrambled anda अंडा भुर्जी", ""),
    ("SR", 173423, "Egg, fried", "Eggs, meat & fish", "egg fried anda अंडा", ""),
    ("FN", 2705956, "Chicken breast, roasted, no skin", "Eggs, meat & fish", "chicken breast roasted grilled चिकन", ""),
    ("FN", 2706227, "Fish, fried", "Eggs, meat & fish", "fish fry fried machli मछली", ""),
    # ---- Snacks & sweets
    ("FN", 2708730, "Samosa", "Snacks & sweets", "samosa समोसा", ""),
    ("FN", 2710066, "Pakora", "Snacks & sweets", "pakora pakoda bhajiya bhaji पकोड़ा", ""),
    ("FN", 2709309, "Chutney", "Snacks & sweets", "chutney chatni चटनी", "t"),
    ("FN", 2705700, "Barfi", "Snacks & sweets", "barfi burfi mithai बर्फी", ""),
    ("FN", 2705686, "Firni (Indian pudding)", "Snacks & sweets", "firni phirni kheer फिरनी", "k"),
    ("FN", 2705685, "Rice pudding (similar to kheer)", "Snacks & sweets", "kheer payasam rice pudding खीर", "k"),
    ("FN", 2709422, "Potato chips", "Snacks & sweets", "chips wafers potato chips चिप्स", ""),
    ("FN", 2709458, "French fries", "Snacks & sweets", "french fries finger chips फ्रेंच फ्राइज़", ""),
    ("FN", 2708219, "Popcorn, air-popped", "Snacks & sweets", "popcorn पॉपकॉर्न", ""),
    ("FN", 2707537, "Peanut butter", "Snacks & sweets", "peanut butter पीनट बटर", ""),
    ("FN", 2710301, "Jam", "Snacks & sweets", "jam जैम", "t"),
    # ---- Vegetables
    ("FN", 2709388, "Potato, boiled", "Vegetables", "aloo alu potato boiled आलू", ""),
    ("SR", 168483, "Sweet potato, baked", "Vegetables", "shakarkand shakarkandi sweet potato शकरकंद", ""),
    ("FN", 2709944, "Okra (bhindi), cooked", "Vegetables", "bhindi okra lady finger भिंडी", "k"),
    ("FN", 2709615, "Spinach (palak), cooked", "Vegetables", "palak spinach पालक", "k"),
    ("FN", 2709897, "Cauliflower (gobi), cooked", "Vegetables", "gobi gobhi phool gobhi cauliflower फूलगोभी", "k"),
    ("FN", 2709889, "Cabbage, cooked", "Vegetables", "cabbage patta gobhi band gobi पत्ता गोभी", "k"),
    ("FN", 2709929, "Brinjal / Eggplant, cooked", "Vegetables", "baingan brinjal eggplant बैंगन", "k"),
    ("SR", 170420, "Green peas, boiled", "Vegetables", "matar mutter peas मटर", "k"),
    ("FN", 2709852, "Green beans, cooked", "Vegetables", "beans phali french beans फली", "k"),
    ("SR", 169233, "Bottle gourd (lauki), boiled", "Vegetables", "lauki doodhi ghiya bottle gourd लौकी", "k"),
    ("SR", 168394, "Bitter gourd (karela), boiled", "Vegetables", "karela bitter gourd करेला", "k"),
    ("SR", 168415, "Sponge gourd (gilki / nenua), boiled", "Vegetables", "gilki nenua turai tori sponge gourd तोरई गिलकी", "k"),
    ("SR", 170484, "Drumstick pods, boiled", "Vegetables", "drumstick sahjan moringa सहजन", "k"),
    ("FN", 2709607, "Mustard greens (sarson), cooked", "Vegetables", "sarson saag mustard greens सरसों", "k"),
    ("SR", 168449, "Pumpkin (kaddu), boiled", "Vegetables", "kaddu sitaphal pumpkin कद्दू", "k"),
    ("SR", 169146, "Beetroot, boiled", "Vegetables", "beetroot chukandar beet चुकंदर", "k"),
    ("SR", 169999, "Sweet corn, boiled", "Vegetables", "corn bhutta makka sweet corn मक्का भुट्टा", "k"),
    ("SR", 170457, "Tomato, raw", "Vegetables", "tomato tamatar टमाटर", ""),
    ("SR", 170000, "Onion, raw", "Vegetables", "onion pyaz pyaaz kanda प्याज", ""),
    ("SR", 168409, "Cucumber, raw", "Vegetables", "cucumber kheera kakdi खीरा", ""),
    ("SR", 170393, "Carrot, raw", "Vegetables", "carrot gajar गाजर", ""),
    ("SR", 169276, "Radish, raw", "Vegetables", "radish mooli muli मूली", ""),
    ("SR", 170427, "Capsicum, green, raw", "Vegetables", "capsicum shimla mirch bell pepper शिमला मिर्च", ""),
    ("SR", 169251, "Mushroom, raw", "Vegetables", "mushroom khumb मशरूम", ""),
    # ---- Fruits
    ("SR", 173944, "Banana", "Fruits", "banana kela केला", ""),
    ("SR", 171688, "Apple, with skin", "Fruits", "apple seb सेब", ""),
    ("SR", 169910, "Mango", "Fruits", "mango aam आम", ""),
    ("SR", 169926, "Papaya", "Fruits", "papaya papita पपीता", ""),
    ("SR", 173044, "Guava", "Fruits", "guava amrud amrood अमरूद", ""),
    ("SR", 169097, "Orange", "Fruits", "orange santra संतरा", ""),
    ("SR", 169134, "Pomegranate", "Fruits", "pomegranate anar अनार", ""),
    ("SR", 167765, "Watermelon", "Fruits", "watermelon tarbooj tarbuz तरबूज", ""),
    ("SR", 168153, "Kiwi", "Fruits", "kiwi कीवी", ""),
    ("SR", 174683, "Grapes", "Fruits", "grapes angoor अंगूर", ""),
    ("SR", 169124, "Pineapple", "Fruits", "pineapple ananas अनानास", ""),
    ("SR", 169092, "Muskmelon (cantaloupe)", "Fruits", "muskmelon kharbuja kharbooja cantaloupe खरबूजा", ""),
    ("SR", 167762, "Strawberries", "Fruits", "strawberry strawberries स्ट्रॉबेरी", ""),
    ("SR", 167776, "Pear", "Fruits", "pear nashpati नाशपाती", ""),
    ("SR", 169086, "Litchi", "Fruits", "litchi lychee leechi लीची", ""),
    ("SR", 174687, "Jackfruit", "Fruits", "jackfruit kathal कटहल", ""),
    ("SR", 167759, "Chikoo (sapota)", "Fruits", "chikoo chiku sapota sapodilla चीकू", ""),
    ("SR", 168150, "Jamun", "Fruits", "jamun java plum जामुन", ""),
    ("SR", 171726, "Dates", "Fruits", "dates khajoor khajur खजूर", ""),
    ("SR", 168165, "Raisins", "Fruits", "raisins kishmish kismis किशमिश", ""),
    ("FN", 2707500, "Coconut, fresh", "Fruits", "coconut nariyal नारियल", ""),
    ("SR", 167747, "Lemon juice", "Fruits", "lemon nimbu nimboo juice नींबू", ""),
    # ---- Nuts & seeds
    ("FN", 2707486, "Almonds", "Nuts & seeds", "almonds badam बादाम", ""),
    ("SR", 170162, "Cashew nuts", "Nuts & seeds", "cashew kaju काजू", ""),
    ("SR", 170187, "Walnuts", "Nuts & seeds", "walnuts akhrot अखरोट", ""),
    ("SR", 172430, "Peanuts, raw", "Nuts & seeds", "peanuts moongfali mungfali groundnut मूंगफली", ""),
    # ---- Oils & sweeteners
    ("SR", 172337, "Mustard oil", "Oils & sweeteners", "mustard oil sarson tel सरसों तेल", ""),
    ("SR", 171025, "Sunflower oil", "Oils & sweeteners", "sunflower oil refined oil tel तेल", ""),
    ("SR", 171412, "Coconut oil", "Oils & sweeteners", "coconut oil nariyal tel नारियल तेल", ""),
    ("SR", 169655, "Sugar", "Oils & sweeteners", "sugar cheeni chini shakkar चीनी", ""),
    ("SR", 169640, "Honey", "Oils & sweeteners", "honey shahad shehad शहद", "t"),
    # ---- Drinks
    ("FN", 2710506, "Tea with milk", "Drinks", "tea chai chay milk tea चाय", "g"),
    ("FN", 2710488, "Black tea, no milk", "Drinks", "black tea chai kali chai चाय", "g"),
    ("FN", 2710375, "Coffee, black", "Drinks", "coffee black कॉफी", "g"),
    ("FN", 2709187, "Orange juice, fresh", "Drinks", "orange juice santra juice जूस", "g"),
    ("FN", 2707572, "Coconut water", "Drinks", "coconut water nariyal pani नारियल पानी", "g"),
    ("FN", 2705405, "Soy milk, unsweetened", "Drinks", "soy milk soya milk सोया मिल्क", "g"),
    ("FN", 2710541, "Cola soft drink", "Drinks", "cola cold drink soft drink pepsi coke कोल्ड ड्रिंक", "g"),
]

# USDA nutrient numbers -> our column names
NUTRIENTS = {"208": "calories", "203": "protein_g", "205": "carbs_g", "204": "fat_g",
             "606": "saturated_fat_g", "291": "fiber_g", "269": "sugar_g", "307": "sodium_mg"}
COLUMNS = ["calories", "protein_g", "carbs_g", "fat_g", "saturated_fat_g", "fiber_g", "sugar_g", "sodium_mg"]

# ---------------------------------------------------------------- load SR Legacy
sr_desc = {}
with open(f"{sr_dir}/food.csv", newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        sr_desc[int(row["fdc_id"])] = row["description"]
nutrient_nbr = {}
with open(f"{sr_dir}/nutrient.csv", newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        nutrient_nbr[row["id"]] = row["nutrient_nbr"].split(".")[0]
wanted_sr = {fid for ds, fid, *_ in FOODS if ds == "SR"}
sr_nutr = {fid: {} for fid in wanted_sr}
with open(f"{sr_dir}/food_nutrient.csv", newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        fid = int(row["fdc_id"])
        if fid in wanted_sr:
            col = NUTRIENTS.get(nutrient_nbr.get(row["nutrient_id"], ""))
            if col and row["amount"] != "":
                sr_nutr[fid][col] = float(row["amount"])
sr_port = {fid: [] for fid in wanted_sr}
with open(f"{sr_dir}/food_portion.csv", newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        fid = int(row["fdc_id"])
        if fid in wanted_sr and row["gram_weight"]:
            amount = float(row["amount"] or 1)
            text = (row["portion_description"] or row["modifier"] or "").strip()
            sr_port[fid].append((f"{amount:g} {text}", float(row["gram_weight"])))

# ---------------------------------------------------------------- load FNDDS
with open(fndds_path, encoding="utf-8") as f:
    survey = {x["fdcId"]: x for x in json.load(f)["SurveyFoods"]}


def fn_nutrients(food):
    out = {}
    for n in food.get("foodNutrients", []):
        col = NUTRIENTS.get(str(n.get("nutrient", {}).get("number", "")).split(".")[0])
        if col and n.get("amount") is not None:
            out[col] = float(n["amount"])
    return out


def fn_portions(food):
    return [(p.get("portionDescription", ""), float(p["gramWeight"]))
            for p in sorted(food.get("foodPortions", []), key=lambda p: p.get("sequenceNumber", 0))
            if p.get("gramWeight")]


# ---------------------------------------------------------------- portions -> units
PIECE_WORDS = r"(piece|each|roti|chapati|chappatti|naan|paratha|puri|idli|dosa|samosa|pakora|egg|fruit|banana|" \
              r"apple|mango|orange|guava|kiwi|kiwifruit|pear|tomato|onion|carrot|cucumber|potato|date|litchi|" \
              r"strawberry|radish|pepper|mushroom|pod|ear|almond|nut|chip|cracker|cookie|bar)"


def leading_qty(text):
    m = re.match(r"\s*(\d+\s+\d+/\d+|\d+/\d+|\d*\.?\d+)", text)
    if not m:
        return 1.0, text
    token = m.group(1)
    qty = float(sum(Fraction(p) for p in token.split())) if "/" in token else float(token)
    return (qty or 1.0), text[m.end():].strip()


# Units that would mislead for a particular food (e.g. USDA's "1 radish" is a 4.5 g red
# radish, not an Indian mooli; "1 fruit" of pineapple is the whole 905 g fruit).
DROP = {
    2705709: ["piece"], 2705630: ["piece"], 2706413: ["slice"], 2709422: ["piece"],
    2709458: ["piece"], 2709897: ["piece"], 2709929: ["piece", "slice"], 170393: ["slice"],
    169276: ["piece", "slice"], 169926: ["piece"], 169124: ["piece", "slice"], 168165: ["piece"],
    2710506: ["piece"], 2710488: ["piece"], 2710375: ["piece"], 2710541: ["piece"],
    2707598: ["cup"], 2705956: ["cup"], 2706227: ["cup"], 169251: ["slice"],
    172185: ["tbsp"], 173424: ["cup"], 172187: ["cup"], 2705740: ["cup"],
}
# Which USDA portion line is "one piece" when the automatic pick is not the natural one.
PIECE_FROM = {2707613: "naan", 2706227: "small/regular fillet", 2708346: "item"}
SPOON_CATEGORIES = {"Dairy", "Oils & sweeteners", "Snacks & sweets"}


def units_from(portions, fid, category, extra):
    """Pick grams per household unit from USDA portion lines."""
    units, piece_rank, slice_rank, fl_oz = {}, 99, 99, None
    for text, grams in portions:
        qty, rest = leading_qty(text.lower())
        per = grams / qty
        if "quantity not specified" in rest or "guideline" in rest:
            continue
        if fid in PIECE_FROM and rest.startswith(PIECE_FROM[fid]):
            units["piece"], piece_rank = per, 0
        elif re.match(r"cup\b", rest):
            units.setdefault("cup", per)
        elif re.match(r"fl oz\b", rest):
            if fl_oz is None or "no ice" in rest:
                fl_oz = per
        elif re.match(r"(tablespoon|tbsp)\b", rest):
            units.setdefault("tbsp", per)
        elif re.match(r"(teaspoon|tsp)\b", rest):
            units.setdefault("tsp", per)
        elif "slice" in rest:
            if re.match(r"medium or regular slice", rest):
                rank = 1
            elif re.match(r"slice\b", rest) and not re.search(r"crust|snack|thin|thick", rest):
                rank = 2
            else:
                rank = None
            if rank is not None and rank < slice_rank:
                units["slice"], slice_rank = per, rank
        else:
            rank = None
            if re.match(r"medium\b", rest):
                rank = 1
            elif re.match(PIECE_WORDS + r"s?\b", rest):
                rank = 2
            elif re.match(r"(regular|whole)\b", rest):
                rank = 3
            elif re.match(r"large\b", rest):
                rank = 4
            elif re.match(r"small\b", rest):
                rank = 5
            if rank is not None and rank < piece_rank:
                units["piece"], piece_rank = per, rank

    if "cup" not in units and fl_oz is not None:
        units["cup"] = fl_oz * 8  # 1 US cup = 8 fl oz
    if "cup" in units and "tbsp" in units and category not in SPOON_CATEGORIES:
        del units["tbsp"]
    if "t" in extra and "tbsp" in units and "tsp" not in units:
        units["tsp"] = units["tbsp"] / 3  # 1 tbsp = 3 tsp
    if "k" in extra and "cup" in units:
        units["katori"] = round(units["cup"] * KATORI_ML / CUP_ML)
    if "g" in extra and "cup" in units:
        units["glass"] = round(units["cup"] * GLASS_ML / CUP_ML)
    for unit in DROP.get(fid, []):
        units.pop(unit, None)
    return units


# ---------------------------------------------------------------- build
rows, problems = [], []
for ds, fid, name, category, terms, extra in FOODS:
    if ds == "SR":
        if fid not in sr_desc:
            problems.append(f"missing SR {fid} ({name})")
            continue
        desc, nutr, portions = sr_desc[fid], sr_nutr[fid], sr_port[fid]
        source = "USDA FoodData Central, SR Legacy (2018)"
    else:
        if fid not in survey:
            problems.append(f"missing FN {fid} ({name})")
            continue
        food = survey[fid]
        desc, nutr, portions = food["description"], fn_nutrients(food), fn_portions(food)
        source = "USDA FoodData Central, FNDDS 2021-2023"
    units = units_from(portions, fid, category, extra)
    units = {k: round(v, 1) for k, v in units.items() if v > 0}
    if "calories" not in nutr:
        problems.append(f"no energy value for {ds} {fid} ({name})")
    rows.append({
        "source_ref": f"{ds}{fid}", "name": name, "category": category, "search_terms": terms,
        "unit_weights": units, "source": source, "usda_description": desc,
        **{c: (round(nutr[c], 2) if c in nutr else None) for c in COLUMNS},
        "_portions": portions,
    })

refs = [r["source_ref"] for r in rows]
if len(set(refs)) != len(refs):
    problems.append("duplicate source_ref")
if len({r["name"] for r in rows}) != len(rows):
    problems.append("duplicate display name")

# ---------------------------------------------------------------- review output
with open(f"{out_dir}/review.txt", "w", encoding="utf-8") as f:
    for r in rows:
        f.write(f"{r['source_ref']:<10} {r['name']}\n    USDA: {r['usda_description']}\n")
        f.write("    per 100 g: " + ", ".join(f"{c}={r[c]}" for c in COLUMNS) + "\n")
        f.write(f"    units: {r['unit_weights']}\n")
        f.write("    portions: " + "; ".join(f"{t} = {g:g} g" for t, g in r["_portions"][:8]) + "\n")


# ---------------------------------------------------------------- SQL + checksum
def sql_text(value):
    return "'" + value.replace("'", "''") + "'"


def sql_num(value):
    return "null" if value is None else f"{value:g}"


def row_signature(r):
    """Must match the SQL expression used to verify the loaded rows."""
    nums = "|".join("" if r[c] is None else f"{r[c]:.2f}" for c in COLUMNS)
    units = ",".join(f"{k}={v:.1f}" for k, v in sorted(r["unit_weights"].items()))
    return f"{r['source_ref']}|{r['name']}|{r['category']}|{r['search_terms']}|{units}|{nums}"


BATCH = 32
batches = [rows[i:i + BATCH] for i in range(0, len(rows), BATCH)]
for index, batch in enumerate(batches, start=1):
    lines = []
    for r in batch:
        units_json = json.dumps(r["unit_weights"], sort_keys=True, separators=(",", ":"))
        lines.append(
            "  (" + ", ".join([
                sql_text(r["source_ref"]), sql_text(r["name"]), sql_text(r["category"]),
                sql_text(r["search_terms"]), sql_text(units_json), sql_text(r["source"]),
                *[sql_num(r[c]) for c in COLUMNS],
            ]) + ")"
        )
    sql = (
        "with data(source_ref, name, category, search_terms, unit_weights, source, "
        + ", ".join(COLUMNS) + ") as (values\n" + ",\n".join(lines) + "\n), ins as (\n"
        "  insert into public.foods (name, category, default_unit, unit_weights, search_terms, source, source_ref, is_verified)\n"
        "  select name, category, 'g', unit_weights::jsonb, search_terms, source, source_ref, false from data\n"
        "  returning id, source_ref\n)\n"
        "insert into public.food_nutrition (food_id, basis, basis_quantity, basis_unit, "
        + ", ".join(COLUMNS) + ", source)\n"
        "select ins.id, 'per_100g', 100, 'g', "
        + ", ".join(f"d.{c}::numeric" for c in COLUMNS)
        + ", d.source\nfrom ins join data d using (source_ref);\n"
    )
    with open(f"{out_dir}/seed_batch_{index}.sql", "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)

signatures = sorted(row_signature(r) for r in rows)
with open(f"{out_dir}/signatures.txt", "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(signatures))
per_row = {r["source_ref"]: hashlib.md5(row_signature(r).encode("utf-8")).hexdigest() for r in rows}
with open(f"{out_dir}/row_md5.json", "w", encoding="utf-8") as f:
    json.dump(per_row, f, indent=0, sort_keys=True)
with open(f"{out_dir}/catalog.json", "w", encoding="utf-8") as f:
    json.dump([{k: v for k, v in r.items() if k != "_portions"} for r in rows], f, ensure_ascii=False, indent=1)

print(f"foods: {len(rows)}  batches: {len(batches)}  problems: {problems or 'none'}")
print("without any household unit:", [r["name"] for r in rows if not r["unit_weights"]])
missing = {c: [r["name"] for r in rows if r[c] is None] for c in COLUMNS}
print("missing values:", {c: v for c, v in missing.items() if v})
print("checksum of all rows:", hashlib.md5("\n".join(signatures).encode("utf-8")).hexdigest())
