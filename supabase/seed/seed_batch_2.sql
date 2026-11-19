with data(source_ref, name, category, search_terms, unit_weights, source, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg) as (values
  ('SR172475', 'Tofu, firm', 'Dals & legumes', 'tofu soya paneer टोफू', '{"cup":252.0}', 'USDA FoodData Central, SR Legacy (2018)', 144, 17.27, 2.78, 8.72, 1.26, 2.3, null, 14),
  ('FN2705385', 'Milk, whole', 'Dairy', 'milk doodh dudh full cream दूध', '{"cup":244.0,"glass":258}', 'USDA FoodData Central, FNDDS 2021-2023', 61, 3.27, 4.63, 3.2, 1.86, 0, 4.81, 38),
  ('FN2705387', 'Milk, low fat (1%)', 'Dairy', 'milk toned low fat doodh दूध', '{"cup":244.0,"glass":258}', 'USDA FoodData Central, FNDDS 2021-2023', 43, 3.38, 5.18, 0.95, 0.57, 0, 4.96, 39),
  ('FN2705418', 'Curd / Yogurt, plain, whole milk', 'Dairy', 'curd dahi yogurt yoghurt दही', '{"cup":245.0,"katori":155}', 'USDA FoodData Central, FNDDS 2021-2023', 78, 3.82, 5.57, 4.48, 2.32, 0, 4.09, 42),
  ('FN2705419', 'Curd / Yogurt, plain, low fat', 'Dairy', 'curd dahi yogurt low fat दही', '{"cup":245.0,"katori":155}', 'USDA FoodData Central, FNDDS 2021-2023', 63, 5.25, 7.04, 1.55, 1, 0, 7.04, 70),
  ('FN2705393', 'Buttermilk', 'Dairy', 'buttermilk chaas chhach chaach mattha छाछ मट्ठा', '{"cup":244.0,"glass":258}', 'USDA FoodData Central, FNDDS 2021-2023', 43, 3.46, 4.81, 1.08, 0.55, 0, 5.36, 92),
  ('FN2710168', 'Ghee', 'Dairy', 'ghee clarified butter घी', '{"cup":224.0,"tbsp":14.0,"tsp":4.7}', 'USDA FoodData Central, FNDDS 2021-2023', 876, 0.28, 0, 99.5, 61.9, 0, 0, 2),
  ('FN2710155', 'Butter', 'Dairy', 'butter makhan makkhan मक्खन', '{"cup":224.0,"tbsp":14.0,"tsp":4.7}', 'USDA FoodData Central, FNDDS 2021-2023', 743, 0.85, 0.06, 82.2, 45.6, 0, 0.58, 524),
  ('FN2705709', 'Cheese, cheddar', 'Dairy', 'cheese चीज़', '{"cup":113.0,"slice":21.0}', 'USDA FoodData Central, FNDDS 2021-2023', 409, 23.3, 2.44, 34, 19.2, 0, 0.33, 654),
  ('FN2705630', 'Ice cream, vanilla', 'Dairy', 'ice cream icecream आइसक्रीम', '{"cup":135.0}', 'USDA FoodData Central, FNDDS 2021-2023', 207, 3.5, 23.6, 11, 6.79, 0.7, 21.2, 80),
  ('FN2709631', 'Palak paneer', 'Curries & dishes', 'palak paneer पालक पनीर', '{"cup":200.0,"katori":127}', 'USDA FoodData Central, FNDDS 2021-2023', 101, 5.42, 4.28, 7.02, 1.81, 0.9, 1.89, 242),
  ('FN2710067', 'Vegetable curry', 'Curries & dishes', 'sabzi sabji vegetable curry mixed veg सब्ज़ी सब्जी', '{"cup":240.0,"katori":152}', 'USDA FoodData Central, FNDDS 2021-2023', 86, 1.6, 8.81, 5.27, 1.26, 1.8, 3.18, 388),
  ('FN2706437', 'Chicken curry', 'Curries & dishes', 'chicken curry murgh चिकन करी', '{"cup":240.0,"katori":152}', 'USDA FoodData Central, FNDDS 2021-2023', 107, 6.48, 6.54, 6.48, 1.56, 1.4, 2.56, 376),
  ('FN2706460', 'Fish curry', 'Curries & dishes', 'fish curry machli machhi मछली करी', '{"cup":240.0,"katori":152}', 'USDA FoodData Central, FNDDS 2021-2023', 93, 4.94, 6.65, 5.42, 1.29, 1.4, 2.56, 351),
  ('FN2706413', 'Mutton with gravy', 'Curries & dishes', 'mutton gosht lamb curry मटन', '{"cup":244.0,"katori":155}', 'USDA FoodData Central, FNDDS 2021-2023', 219, 17.3, 1.58, 15.4, 6.34, 0, 0.09, 359),
  ('SR173424', 'Egg, boiled', 'Eggs, meat & fish', 'egg anda boiled अंडा', '{"piece":50.0}', 'USDA FoodData Central, SR Legacy (2018)', 155, 12.58, 1.12, 10.61, 3.27, 0, 1.12, 124),
  ('SR172185', 'Egg omelette', 'Eggs, meat & fish', 'omelette omelet egg anda आमलेट', '{"piece":61.0}', 'USDA FoodData Central, SR Legacy (2018)', 154, 10.57, 0.64, 11.66, 3.32, 0, 0.31, 155),
  ('SR172187', 'Egg, scrambled', 'Eggs, meat & fish', 'egg bhurji scrambled anda अंडा भुर्जी', '{"piece":61.0}', 'USDA FoodData Central, SR Legacy (2018)', 149, 9.99, 1.61, 10.98, 3.33, 0, 1.39, 145),
  ('SR173423', 'Egg, fried', 'Eggs, meat & fish', 'egg fried anda अंडा', '{"piece":46.0}', 'USDA FoodData Central, SR Legacy (2018)', 196, 13.61, 0.83, 14.84, 4.32, 0, 0.4, 207),
  ('FN2705956', 'Chicken breast, roasted, no skin', 'Eggs, meat & fish', 'chicken breast roasted grilled चिकन', '{"piece":120.0}', 'USDA FoodData Central, FNDDS 2021-2023', 161, 30.2, 0, 3.52, 0.76, 0, 0, 360),
  ('FN2706227', 'Fish, fried', 'Eggs, meat & fish', 'fish fry fried machli मछली', '{"piece":90.0}', 'USDA FoodData Central, FNDDS 2021-2023', 269, 16, 11.7, 17.2, 2.83, 0.5, 0.2, 399),
  ('FN2708730', 'Samosa', 'Snacks & sweets', 'samosa समोसा', '{"piece":100.0}', 'USDA FoodData Central, FNDDS 2021-2023', 310, 5.14, 33.2, 17.5, 4.41, 1.8, 1.28, 388),
  ('FN2710066', 'Pakora', 'Snacks & sweets', 'pakora pakoda bhajiya bhaji पकोड़ा', '{"piece":12.0}', 'USDA FoodData Central, FNDDS 2021-2023', 125, 4.92, 16.2, 4.77, 0.6, 3.2, 2.97, 380),
  ('FN2709309', 'Chutney', 'Snacks & sweets', 'chutney chatni चटनी', '{"tbsp":16.0,"tsp":5.3}', 'USDA FoodData Central, FNDDS 2021-2023', 246, 0.33, 60.6, 0.06, 0.01, 1, 42.7, 802),
  ('FN2705700', 'Barfi', 'Snacks & sweets', 'barfi burfi mithai बर्फी', '{"piece":45.0}', 'USDA FoodData Central, FNDDS 2021-2023', 284, 5.42, 40.4, 11.4, 6.11, 0.4, 37, 71),
  ('FN2705686', 'Firni (Indian pudding)', 'Snacks & sweets', 'firni phirni kheer फिरनी', '{"cup":260.0,"katori":165}', 'USDA FoodData Central, FNDDS 2021-2023', 144, 3.58, 25.1, 3.11, 1.49, 0.3, 15.7, 30),
  ('FN2705685', 'Rice pudding (similar to kheer)', 'Snacks & sweets', 'kheer payasam rice pudding खीर', '{"cup":260.0,"katori":165}', 'USDA FoodData Central, FNDDS 2021-2023', 108, 3.23, 18.4, 2.15, 1.21, 0.3, 11.6, 97),
  ('FN2709422', 'Potato chips', 'Snacks & sweets', 'chips wafers potato chips चिप्स', '{"cup":25.0}', 'USDA FoodData Central, FNDDS 2021-2023', 532, 6.39, 53.8, 34, 3.4, 3.1, 0.33, 527),
  ('FN2709458', 'French fries', 'Snacks & sweets', 'french fries finger chips फ्रेंच फ्राइज़', '{"cup":60.0}', 'USDA FoodData Central, FNDDS 2021-2023', 198, 1.93, 18.5, 13.1, 1.76, 1.6, 1.25, 141),
  ('FN2708219', 'Popcorn, air-popped', 'Snacks & sweets', 'popcorn पॉपकॉर्न', '{"cup":8.0}', 'USDA FoodData Central, FNDDS 2021-2023', 385, 12.9, 77.5, 4.52, 0.63, 14.4, 0.87, 162),
  ('FN2707537', 'Peanut butter', 'Snacks & sweets', 'peanut butter पीनट बटर', '{"tbsp":16.0}', 'USDA FoodData Central, FNDDS 2021-2023', 598, 22.2, 22.3, 51.4, 10.3, 5, 10.5, 426),
  ('FN2710301', 'Jam', 'Snacks & sweets', 'jam जैम', '{"tbsp":20.0,"tsp":6.7}', 'USDA FoodData Central, FNDDS 2021-2023', 278, 0.37, 68.9, 0.07, 0.01, 1.1, 48.5, 32)
), ins as (
  insert into public.foods (name, category, default_unit, unit_weights, search_terms, source, source_ref, is_verified)
  select name, category, 'g', unit_weights::jsonb, search_terms, source, source_ref, false from data
  returning id, source_ref
)
insert into public.food_nutrition (food_id, basis, basis_quantity, basis_unit, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg, source)
select ins.id, 'per_100g', 100, 'g', d.calories::numeric, d.protein_g::numeric, d.carbs_g::numeric, d.fat_g::numeric, d.saturated_fat_g::numeric, d.fiber_g::numeric, d.sugar_g::numeric, d.sodium_mg::numeric, d.source
from ins join data d using (source_ref);
