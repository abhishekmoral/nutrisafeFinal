with data(source_ref, name, category, search_terms, unit_weights, source, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg) as (values
  ('FN2707713', 'Roti / Chapati', 'Breads & grains', 'roti chapati chapatti phulka रोटी चपाती फुलका', '{"piece":40.0}', 'USDA FoodData Central, FNDDS 2021-2023', 299, 7.85, 46.1, 9.2, 3.31, 9.7, 2.93, 298),
  ('FN2707715', 'Paratha', 'Breads & grains', 'paratha parantha parotta पराठा', '{"piece":70.0}', 'USDA FoodData Central, FNDDS 2021-2023', 326, 6.36, 45.4, 13.2, 5.83, 9.6, 4.15, 452),
  ('FN2707613', 'Naan', 'Breads & grains', 'naan nan नान', '{"piece":177.0}', 'USDA FoodData Central, FNDDS 2021-2023', 311, 11.1, 50.2, 7.28, 3.16, 5.2, 3.7, 508),
  ('FN2707714', 'Puri', 'Breads & grains', 'puri poori पूरी', '{"piece":36.0}', 'USDA FoodData Central, FNDDS 2021-2023', 409, 6.84, 39.2, 24.9, 3.34, 3.5, 0.18, 170),
  ('FN2708408', 'Rice, white, cooked', 'Breads & grains', 'rice chawal chaval bhaat bhat चावल भात', '{"cup":158.0,"katori":100}', 'USDA FoodData Central, FNDDS 2021-2023', 129, 2.67, 28, 0.28, 0.08, 0.4, 0.05, 245),
  ('FN2708414', 'Rice, brown, cooked', 'Breads & grains', 'brown rice chawal ब्राउन राइस', '{"cup":195.0,"katori":124}', 'USDA FoodData Central, FNDDS 2021-2023', 123, 2.43, 25.8, 1.11, 0.2, 1, 0.22, 201),
  ('FN2708951', 'Fried rice, vegetable', 'Breads & grains', 'fried rice veg फ्राइड राइस', '{"cup":166.0,"katori":105}', 'USDA FoodData Central, FNDDS 2021-2023', 174, 3.84, 32.5, 3.19, 0.49, 1.1, 0.62, 361),
  ('FN2709077', 'Pulao (rice pilaf)', 'Breads & grains', 'pulao pulav pilaf पुलाव', '{"cup":206.0,"katori":131}', 'USDA FoodData Central, FNDDS 2021-2023', 137, 3.29, 24.1, 3.03, 0.44, 0.4, 0.48, 414),
  ('FN2708985', 'Biryani, vegetable', 'Breads & grains', 'veg biryani biriyani बिरयानी', '{"cup":172.0,"katori":109}', 'USDA FoodData Central, FNDDS 2021-2023', 109, 1.93, 17.9, 3.2, 1.7, 1.2, 1.18, 177),
  ('FN2706538', 'Biryani, chicken', 'Breads & grains', 'chicken biryani biriyani बिरयानी', '{"cup":196.0,"katori":124}', 'USDA FoodData Central, FNDDS 2021-2023', 104, 7.15, 13.6, 2.38, 0.91, 1.1, 1.88, 161),
  ('FN2706490', 'Biryani, meat', 'Breads & grains', 'mutton biryani biriyani meat बिरयानी', '{"cup":196.0,"katori":124}', 'USDA FoodData Central, FNDDS 2021-2023', 145, 8.5, 12.2, 6.79, 2.97, 1, 1.69, 98),
  ('FN2708347', 'Dosa, plain', 'Breads & grains', 'dosa dosai plain डोसा', '{"piece":80.0}', 'USDA FoodData Central, FNDDS 2021-2023', 210, 5.7, 37, 4.05, 0.58, 1.8, 0.3, 309),
  ('FN2709129', 'Dosa, with filling (masala dosa)', 'Breads & grains', 'masala dosa dosai मसाला डोसा', '{"piece":267.0}', 'USDA FoodData Central, FNDDS 2021-2023', 184, 5.46, 30.8, 4.27, 0.58, 2.2, 1.1, 330),
  ('FN2708346', 'Idli', 'Breads & grains', 'idli idly इडली', '{"piece":38.0}', 'USDA FoodData Central, FNDDS 2021-2023', 128, 6.36, 25, 0.35, 0.06, 5.8, 1.85, 252),
  ('FN2709128', 'Upma', 'Breads & grains', 'upma uppuma उपमा', '{"cup":170.0,"katori":108}', 'USDA FoodData Central, FNDDS 2021-2023', 87, 1.98, 13.8, 2.64, 0.36, 1.3, 1.61, 98),
  ('FN2708381', 'Oats porridge, made with water', 'Breads & grains', 'oats oatmeal porridge ओट्स', '{"cup":240.0,"katori":152}', 'USDA FoodData Central, FNDDS 2021-2023', 64, 2.21, 11.4, 1.09, 0.19, 1.7, 0.17, 70),
  ('FN2708383', 'Oats porridge, made with milk', 'Breads & grains', 'oats oatmeal porridge milk ओट्स', '{"cup":240.0,"katori":152}', 'USDA FoodData Central, FNDDS 2021-2023', 116, 5.56, 16.2, 3.25, 1.44, 1.7, 5.08, 105),
  ('FN2708489', 'Oats, dry', 'Breads & grains', 'oats raw rolled ओट्स', '{"cup":80.0}', 'USDA FoodData Central, FNDDS 2021-2023', 379, 13.2, 67.7, 6.52, 1.11, 10.1, 0.99, 6),
  ('FN2707598', 'Bread, white', 'Breads & grains', 'bread white double roti pav ब्रेड', '{"slice":28.0}', 'USDA FoodData Central, FNDDS 2021-2023', 267, 9.43, 49.2, 3.59, 0.82, 2.3, 5.34, 450),
  ('FN2707709', 'Bread, whole wheat (brown bread)', 'Breads & grains', 'brown bread whole wheat atta bread ब्रेड', '{"slice":36.0}', 'USDA FoodData Central, FNDDS 2021-2023', 254, 12.3, 43.1, 3.55, 0.73, 6, 4.41, 430),
  ('FN2708352', 'Noodles, cooked', 'Breads & grains', 'noodles chowmein नूडल्स', '{"cup":160.0,"katori":101}', 'USDA FoodData Central, FNDDS 2021-2023', 137, 4.51, 25, 2.06, 0.42, 1.2, 0.4, 236),
  ('FN2708453', 'Corn flakes', 'Breads & grains', 'cornflakes corn flakes cereal कॉर्न फ्लेक्स', '{"cup":30.0}', 'USDA FoodData Central, FNDDS 2021-2023', 365, 6.4, 79.5, 1.6, 0.2, 3.5, 9.44, 703),
  ('FN2707427', 'Dal', 'Dals & legumes', 'dal daal dhal lentil दाल', '{"cup":240.0,"katori":152}', 'USDA FoodData Central, FNDDS 2021-2023', 145, 8.6, 19.2, 4.31, 2.51, 7.5, 1.71, 309),
  ('FN2707431', 'Lentil curry', 'Dals & legumes', 'dal curry masoor lentil curry दाल', '{"cup":240.0,"katori":152}', 'USDA FoodData Central, FNDDS 2021-2023', 111, 3.68, 12.3, 5.65, 1.29, 3.4, 3.21, 383),
  ('FN2707430', 'Sambar', 'Dals & legumes', 'sambar sambhar सांभर', '{"cup":248.0,"katori":157}', 'USDA FoodData Central, FNDDS 2021-2023', 86, 4.33, 11.8, 2.71, 0.37, 4, 1.97, 207),
  ('SR172421', 'Lentils (masoor), boiled', 'Dals & legumes', 'masoor lentils boiled मसूर', '{"cup":198.0,"katori":126}', 'USDA FoodData Central, SR Legacy (2018)', 116, 9.02, 20.13, 0.38, 0.05, 7.9, 1.8, 2),
  ('SR173757', 'Chickpeas (chana), boiled', 'Dals & legumes', 'chana chole chhole kabuli chickpeas चना छोले', '{"cup":164.0,"katori":104}', 'USDA FoodData Central, SR Legacy (2018)', 164, 8.86, 27.42, 2.59, 0.27, 7.6, 4.8, 7),
  ('SR173740', 'Kidney beans (rajma), boiled', 'Dals & legumes', 'rajma kidney beans राजमा', '{"cup":177.0,"katori":112}', 'USDA FoodData Central, SR Legacy (2018)', 127, 8.67, 22.8, 0.5, 0.07, 6.4, 0.32, 1),
  ('SR174257', 'Green gram (moong), boiled', 'Dals & legumes', 'moong mung green gram मूंग', '{"cup":202.0,"katori":128}', 'USDA FoodData Central, SR Legacy (2018)', 105, 7.02, 19.15, 0.38, 0.12, 7.6, 2, 2),
  ('SR172427', 'Black gram (urad), boiled', 'Dals & legumes', 'urad black gram उड़द', '{"cup":180.0,"katori":114}', 'USDA FoodData Central, SR Legacy (2018)', 105, 7.54, 18.34, 0.55, 0.04, 6.4, 2.01, 7),
  ('FN2709632', 'Chana saag', 'Dals & legumes', 'chana saag channa चना साग', '{"cup":245.0,"katori":155}', 'USDA FoodData Central, FNDDS 2021-2023', 89, 4.1, 8.79, 4.33, 0.55, 3, 1.81, 270),
  ('FN2709768', 'Bean sprouts, raw', 'Dals & legumes', 'sprouts ankurit moong sprouts अंकुरित', '{"cup":90.0,"katori":57}', 'USDA FoodData Central, FNDDS 2021-2023', 30, 3.04, 5.94, 0.18, 0.05, 1.8, 4.13, 6)
), ins as (
  insert into public.foods (name, category, default_unit, unit_weights, search_terms, source, source_ref, is_verified)
  select name, category, 'g', unit_weights::jsonb, search_terms, source, source_ref, false from data
  returning id, source_ref
)
insert into public.food_nutrition (food_id, basis, basis_quantity, basis_unit, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg, source)
select ins.id, 'per_100g', 100, 'g', d.calories::numeric, d.protein_g::numeric, d.carbs_g::numeric, d.fat_g::numeric, d.saturated_fat_g::numeric, d.fiber_g::numeric, d.sugar_g::numeric, d.sodium_mg::numeric, d.source
from ins join data d using (source_ref);
