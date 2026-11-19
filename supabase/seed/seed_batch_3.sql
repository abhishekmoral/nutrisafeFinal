with data(source_ref, name, category, search_terms, unit_weights, source, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg) as (values
  ('FN2709388', 'Potato, boiled', 'Vegetables', 'aloo alu potato boiled आलू', '{"cup":160.0,"piece":170.0}', 'USDA FoodData Central, FNDDS 2021-2023', 93, 1.95, 21.5, 0.1, 0.03, 1.5, 1.69, 159),
  ('SR168483', 'Sweet potato, baked', 'Vegetables', 'shakarkand shakarkandi sweet potato शकरकंद', '{"cup":200.0,"piece":114.0}', 'USDA FoodData Central, SR Legacy (2018)', 90, 2.01, 20.71, 0.15, 0.05, 3.3, 6.48, 36),
  ('FN2709944', 'Okra (bhindi), cooked', 'Vegetables', 'bhindi okra lady finger भिंडी', '{"cup":160.0,"katori":101,"piece":10.0}', 'USDA FoodData Central, FNDDS 2021-2023', 35, 2.07, 7.99, 0.2, 0.03, 3.4, 1.59, 132),
  ('FN2709615', 'Spinach (palak), cooked', 'Vegetables', 'palak spinach पालक', '{"cup":180.0,"katori":114}', 'USDA FoodData Central, FNDDS 2021-2023', 33, 3.41, 3.1, 0.7, 0.07, 1.9, 0.49, 262),
  ('FN2709897', 'Cauliflower (gobi), cooked', 'Vegetables', 'gobi gobhi phool gobhi cauliflower फूलगोभी', '{"cup":155.0,"katori":98}', 'USDA FoodData Central, FNDDS 2021-2023', 26, 1.99, 5.16, 0.29, 0.14, 2.1, 1.98, 152),
  ('FN2709889', 'Cabbage, cooked', 'Vegetables', 'cabbage patta gobhi band gobi पत्ता गोभी', '{"cup":150.0,"katori":95}', 'USDA FoodData Central, FNDDS 2021-2023', 32, 1, 6.63, 0.24, 0.04, 2.6, 3.32, 137),
  ('FN2709929', 'Brinjal / Eggplant, cooked', 'Vegetables', 'baingan brinjal eggplant बैंगन', '{"cup":95.0,"katori":60}', 'USDA FoodData Central, FNDDS 2021-2023', 27, 1.05, 6.3, 0.19, 0.04, 3.2, 3.78, 127),
  ('SR170420', 'Green peas, boiled', 'Vegetables', 'matar mutter peas मटर', '{"cup":160.0,"katori":101}', 'USDA FoodData Central, SR Legacy (2018)', 84, 5.36, 15.63, 0.22, 0.04, 5.5, 5.93, 3),
  ('FN2709852', 'Green beans, cooked', 'Vegetables', 'beans phali french beans फली', '{"cup":140.0,"katori":89}', 'USDA FoodData Central, FNDDS 2021-2023', 42, 2.05, 7.7, 0.29, 0.05, 3.1, 2.42, 121),
  ('SR169233', 'Bottle gourd (lauki), boiled', 'Vegetables', 'lauki doodhi ghiya bottle gourd लौकी', '{"cup":146.0,"katori":93}', 'USDA FoodData Central, SR Legacy (2018)', 15, 0.6, 3.69, 0.02, 0, 1.2, null, 2),
  ('SR168394', 'Bitter gourd (karela), boiled', 'Vegetables', 'karela bitter gourd करेला', '{"cup":124.0,"katori":79}', 'USDA FoodData Central, SR Legacy (2018)', 19, 0.84, 4.32, 0.18, 0.01, 2, 1.95, 6),
  ('SR168415', 'Sponge gourd (gilki / nenua), boiled', 'Vegetables', 'gilki nenua turai tori sponge gourd तोरई गिलकी', '{"cup":178.0,"katori":113}', 'USDA FoodData Central, SR Legacy (2018)', 56, 0.66, 14.34, 0.34, 0.03, 2.9, 5.17, 21),
  ('SR170484', 'Drumstick pods, boiled', 'Vegetables', 'drumstick sahjan moringa सहजन', '{"cup":118.0,"katori":75}', 'USDA FoodData Central, SR Legacy (2018)', 36, 2.09, 8.18, 0.19, 0.03, 4.2, null, 43),
  ('FN2709607', 'Mustard greens (sarson), cooked', 'Vegetables', 'sarson saag mustard greens सरसों', '{"cup":140.0,"katori":89}', 'USDA FoodData Central, FNDDS 2021-2023', 29, 3.07, 5.01, 0.45, 0.01, 3.4, 1.42, 146),
  ('SR168449', 'Pumpkin (kaddu), boiled', 'Vegetables', 'kaddu sitaphal pumpkin कद्दू', '{"cup":245.0,"katori":155}', 'USDA FoodData Central, SR Legacy (2018)', 20, 0.72, 4.9, 0.07, 0.04, 1.1, 2.08, 1),
  ('SR169146', 'Beetroot, boiled', 'Vegetables', 'beetroot chukandar beet चुकंदर', '{"cup":170.0,"katori":108}', 'USDA FoodData Central, SR Legacy (2018)', 44, 1.68, 9.96, 0.18, 0.03, 2, 7.96, 77),
  ('SR169999', 'Sweet corn, boiled', 'Vegetables', 'corn bhutta makka sweet corn मक्का भुट्टा', '{"cup":149.0,"katori":94,"piece":89.0}', 'USDA FoodData Central, SR Legacy (2018)', 96, 3.41, 20.98, 1.5, 0.2, 2.4, 4.54, 1),
  ('SR170457', 'Tomato, raw', 'Vegetables', 'tomato tamatar टमाटर', '{"cup":149.0,"piece":123.0}', 'USDA FoodData Central, SR Legacy (2018)', 18, 0.88, 3.89, 0.2, 0.03, 1.2, 2.63, 5),
  ('SR170000', 'Onion, raw', 'Vegetables', 'onion pyaz pyaaz kanda प्याज', '{"cup":160.0,"piece":110.0}', 'USDA FoodData Central, SR Legacy (2018)', 40, 1.1, 9.34, 0.1, 0.04, 1.7, 4.24, 4),
  ('SR168409', 'Cucumber, raw', 'Vegetables', 'cucumber kheera kakdi खीरा', '{"cup":104.0,"piece":301.0}', 'USDA FoodData Central, SR Legacy (2018)', 15, 0.65, 3.63, 0.11, 0.04, 0.5, 1.67, 2),
  ('SR170393', 'Carrot, raw', 'Vegetables', 'carrot gajar गाजर', '{"cup":128.0,"piece":61.0}', 'USDA FoodData Central, SR Legacy (2018)', 41, 0.93, 9.58, 0.24, 0.03, 2.8, 4.74, 69),
  ('SR169276', 'Radish, raw', 'Vegetables', 'radish mooli muli मूली', '{"cup":116.0}', 'USDA FoodData Central, SR Legacy (2018)', 16, 0.68, 3.4, 0.1, 0.03, 1.6, 1.86, 39),
  ('SR170427', 'Capsicum, green, raw', 'Vegetables', 'capsicum shimla mirch bell pepper शिमला मिर्च', '{"cup":149.0,"piece":119.0}', 'USDA FoodData Central, SR Legacy (2018)', 20, 0.86, 4.64, 0.17, 0.06, 1.7, 2.4, 3),
  ('SR169251', 'Mushroom, raw', 'Vegetables', 'mushroom khumb मशरूम', '{"cup":70.0,"piece":18.0}', 'USDA FoodData Central, SR Legacy (2018)', 22, 3.09, 3.26, 0.34, 0.05, 1, 1.98, 5),
  ('SR173944', 'Banana', 'Fruits', 'banana kela केला', '{"cup":225.0,"piece":118.0}', 'USDA FoodData Central, SR Legacy (2018)', 89, 1.09, 22.84, 0.33, 0.11, 2.6, 12.23, 1),
  ('SR171688', 'Apple, with skin', 'Fruits', 'apple seb सेब', '{"cup":125.0,"piece":182.0}', 'USDA FoodData Central, SR Legacy (2018)', 52, 0.26, 13.81, 0.17, 0.03, 2.4, 10.39, 1),
  ('SR169910', 'Mango', 'Fruits', 'mango aam आम', '{"cup":165.0,"piece":336.0}', 'USDA FoodData Central, SR Legacy (2018)', 60, 0.82, 14.98, 0.38, 0.09, 1.6, 13.66, 1),
  ('SR169926', 'Papaya', 'Fruits', 'papaya papita पपीता', '{"cup":145.0}', 'USDA FoodData Central, SR Legacy (2018)', 43, 0.47, 10.82, 0.26, 0.08, 1.7, 7.82, 8),
  ('SR173044', 'Guava', 'Fruits', 'guava amrud amrood अमरूद', '{"cup":165.0,"piece":55.0}', 'USDA FoodData Central, SR Legacy (2018)', 68, 2.55, 14.32, 0.95, 0.27, 5.4, 8.92, 2),
  ('SR169097', 'Orange', 'Fruits', 'orange santra संतरा', '{"cup":180.0,"piece":131.0}', 'USDA FoodData Central, SR Legacy (2018)', 47, 0.94, 11.75, 0.12, 0.01, 2.4, 9.35, 0),
  ('SR169134', 'Pomegranate', 'Fruits', 'pomegranate anar अनार', '{"cup":174.0}', 'USDA FoodData Central, SR Legacy (2018)', 83, 1.67, 18.7, 1.17, 0.12, 4, 13.67, 3),
  ('SR167765', 'Watermelon', 'Fruits', 'watermelon tarbooj tarbuz तरबूज', '{"cup":154.0}', 'USDA FoodData Central, SR Legacy (2018)', 30, 0.61, 7.55, 0.15, 0.02, 0.4, 6.2, 1)
), ins as (
  insert into public.foods (name, category, default_unit, unit_weights, search_terms, source, source_ref, is_verified)
  select name, category, 'g', unit_weights::jsonb, search_terms, source, source_ref, false from data
  returning id, source_ref
)
insert into public.food_nutrition (food_id, basis, basis_quantity, basis_unit, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg, source)
select ins.id, 'per_100g', 100, 'g', d.calories::numeric, d.protein_g::numeric, d.carbs_g::numeric, d.fat_g::numeric, d.saturated_fat_g::numeric, d.fiber_g::numeric, d.sugar_g::numeric, d.sodium_mg::numeric, d.source
from ins join data d using (source_ref);
