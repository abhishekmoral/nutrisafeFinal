with data(source_ref, name, category, search_terms, unit_weights, source, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg) as (values
  ('SR168153', 'Kiwi', 'Fruits', 'kiwi कीवी', '{"cup":180.0,"piece":69.0}', 'USDA FoodData Central, SR Legacy (2018)', 61, 1.14, 14.66, 0.52, 0.03, 3, 8.99, 3),
  ('SR174683', 'Grapes', 'Fruits', 'grapes angoor अंगूर', '{"cup":151.0}', 'USDA FoodData Central, SR Legacy (2018)', 69, 0.72, 18.1, 0.16, 0.05, 0.9, 15.48, 2),
  ('SR169124', 'Pineapple', 'Fruits', 'pineapple ananas अनानास', '{"cup":165.0}', 'USDA FoodData Central, SR Legacy (2018)', 50, 0.54, 13.12, 0.12, 0.01, 1.4, 9.85, 1),
  ('SR169092', 'Muskmelon (cantaloupe)', 'Fruits', 'muskmelon kharbuja kharbooja cantaloupe खरबूजा', '{"cup":177.0}', 'USDA FoodData Central, SR Legacy (2018)', 34, 0.84, 8.16, 0.19, 0.05, 0.9, 7.86, 16),
  ('SR167762', 'Strawberries', 'Fruits', 'strawberry strawberries स्ट्रॉबेरी', '{"cup":152.0,"piece":12.0}', 'USDA FoodData Central, SR Legacy (2018)', 32, 0.67, 7.68, 0.3, 0.01, 2, 4.89, 1),
  ('SR167776', 'Pear', 'Fruits', 'pear nashpati नाशपाती', '{"cup":140.0,"piece":177.0}', 'USDA FoodData Central, SR Legacy (2018)', 63, 0.39, 15.01, 0.16, null, 3.1, 9.69, 1),
  ('SR169086', 'Litchi', 'Fruits', 'litchi lychee leechi लीची', '{"cup":190.0,"piece":9.6}', 'USDA FoodData Central, SR Legacy (2018)', 66, 0.83, 16.53, 0.44, 0.1, 1.3, 15.23, 1),
  ('SR174687', 'Jackfruit', 'Fruits', 'jackfruit kathal कटहल', '{"cup":165.0}', 'USDA FoodData Central, SR Legacy (2018)', 95, 1.72, 23.25, 0.64, 0.2, 1.5, 19.08, 2),
  ('SR167759', 'Chikoo (sapota)', 'Fruits', 'chikoo chiku sapota sapodilla चीकू', '{"cup":241.0}', 'USDA FoodData Central, SR Legacy (2018)', 83, 0.44, 19.96, 1.1, 0.19, 5.3, null, 12),
  ('SR168150', 'Jamun', 'Fruits', 'jamun java plum जामुन', '{"cup":135.0,"piece":3.0}', 'USDA FoodData Central, SR Legacy (2018)', 60, 0.72, 15.56, 0.23, null, null, null, 14),
  ('SR171726', 'Dates', 'Fruits', 'dates khajoor khajur खजूर', '{"cup":147.0,"piece":7.1}', 'USDA FoodData Central, SR Legacy (2018)', 282, 2.45, 75.03, 0.39, 0.03, 8, 63.35, 2),
  ('SR168165', 'Raisins', 'Fruits', 'raisins kishmish kismis किशमिश', '{"cup":165.0}', 'USDA FoodData Central, SR Legacy (2018)', 299, 3.3, 79.32, 0.25, 0.09, 4.5, 65.18, 26),
  ('FN2707500', 'Coconut, fresh', 'Fruits', 'coconut nariyal नारियल', '{"cup":85.0}', 'USDA FoodData Central, FNDDS 2021-2023', 354, 3.33, 15.2, 33.5, 29.7, 9, 6.23, 20),
  ('SR167747', 'Lemon juice', 'Fruits', 'lemon nimbu nimboo juice नींबू', '{"cup":244.0}', 'USDA FoodData Central, SR Legacy (2018)', 22, 0.35, 6.9, 0.24, 0.04, 0.3, 2.52, 1),
  ('FN2707486', 'Almonds', 'Nuts & seeds', 'almonds badam बादाम', '{"cup":141.0,"piece":1.2}', 'USDA FoodData Central, FNDDS 2021-2023', 626, 21.4, 20, 51.1, 3.78, 10.8, 4.35, 0),
  ('SR170162', 'Cashew nuts', 'Nuts & seeds', 'cashew kaju काजू', '{}', 'USDA FoodData Central, SR Legacy (2018)', 553, 18.22, 30.19, 43.85, 7.78, 3.3, 5.91, 12),
  ('SR170187', 'Walnuts', 'Nuts & seeds', 'walnuts akhrot अखरोट', '{"cup":117.0}', 'USDA FoodData Central, SR Legacy (2018)', 654, 15.23, 13.71, 65.21, 6.13, 6.7, 2.61, 2),
  ('SR172430', 'Peanuts, raw', 'Nuts & seeds', 'peanuts moongfali mungfali groundnut मूंगफली', '{"cup":146.0}', 'USDA FoodData Central, SR Legacy (2018)', 567, 25.8, 16.13, 49.24, 6.28, 8.5, 4.72, 18),
  ('SR172337', 'Mustard oil', 'Oils & sweeteners', 'mustard oil sarson tel सरसों तेल', '{"cup":218.0,"tbsp":14.0,"tsp":4.5}', 'USDA FoodData Central, SR Legacy (2018)', 884, 0, 0, 100, 11.58, 0, null, 0),
  ('SR171025', 'Sunflower oil', 'Oils & sweeteners', 'sunflower oil refined oil tel तेल', '{"cup":218.0,"tbsp":13.6,"tsp":4.5}', 'USDA FoodData Central, SR Legacy (2018)', 884, 0, 0, 100, 10.3, 0, 0, 0),
  ('SR171412', 'Coconut oil', 'Oils & sweeteners', 'coconut oil nariyal tel नारियल तेल', '{"cup":218.0,"tbsp":13.6,"tsp":4.5}', 'USDA FoodData Central, SR Legacy (2018)', 892, 0, 0, 99.06, 82.47, 0, 0, 0),
  ('SR169655', 'Sugar', 'Oils & sweeteners', 'sugar cheeni chini shakkar चीनी', '{"cup":200.0,"tsp":4.2}', 'USDA FoodData Central, SR Legacy (2018)', 387, 0, 99.98, 0, 0, 0, 99.8, 1),
  ('SR169640', 'Honey', 'Oils & sweeteners', 'honey shahad shehad शहद', '{"cup":339.0,"tbsp":21.0,"tsp":7.0}', 'USDA FoodData Central, SR Legacy (2018)', 304, 0.3, 82.4, 0, 0, 0.2, 82.12, 4),
  ('FN2710506', 'Tea with milk', 'Drinks', 'tea chai chay milk tea चाय', '{"cup":240.0,"glass":254}', 'USDA FoodData Central, FNDDS 2021-2023', 51, 1.58, 8.95, 1.05, 0.6, 0.1, 8.72, 20),
  ('FN2710488', 'Black tea, no milk', 'Drinks', 'black tea chai kali chai चाय', '{"cup":240.0,"glass":254}', 'USDA FoodData Central, FNDDS 2021-2023', 1, 0, 0.3, 0, 0, 0, 0, 3),
  ('FN2710375', 'Coffee, black', 'Drinks', 'coffee black कॉफी', '{"cup":240.0,"glass":254}', 'USDA FoodData Central, FNDDS 2021-2023', 1, 0.12, 0, 0.02, 0, 0, 0, 2),
  ('FN2709187', 'Orange juice, fresh', 'Drinks', 'orange juice santra juice जूस', '{"cup":248.0,"glass":262}', 'USDA FoodData Central, FNDDS 2021-2023', 47, 0.81, 10, 0.36, 0.01, 0.3, 8.08, 0),
  ('FN2707572', 'Coconut water', 'Drinks', 'coconut water nariyal pani नारियल पानी', '{"cup":240.0,"glass":254}', 'USDA FoodData Central, FNDDS 2021-2023', 18, 0.22, 4.24, 0, 0, 0, 3.92, 26),
  ('FN2705405', 'Soy milk, unsweetened', 'Drinks', 'soy milk soya milk सोया मिल्क', '{"cup":244.0,"glass":258}', 'USDA FoodData Central, FNDDS 2021-2023', 38, 3.55, 1.29, 2.12, 0.31, 0, 0.56, 34),
  ('FN2710541', 'Cola soft drink', 'Drinks', 'cola cold drink soft drink pepsi coke कोल्ड ड्रिंक', '{"cup":248.0,"glass":262}', 'USDA FoodData Central, FNDDS 2021-2023', 42, 0, 10.4, 0.25, 0, 0, 9.94, 3)
), ins as (
  insert into public.foods (name, category, default_unit, unit_weights, search_terms, source, source_ref, is_verified)
  select name, category, 'g', unit_weights::jsonb, search_terms, source, source_ref, false from data
  returning id, source_ref
)
insert into public.food_nutrition (food_id, basis, basis_quantity, basis_unit, calories, protein_g, carbs_g, fat_g, saturated_fat_g, fiber_g, sugar_g, sodium_mg, source)
select ins.id, 'per_100g', 100, 'g', d.calories::numeric, d.protein_g::numeric, d.carbs_g::numeric, d.fat_g::numeric, d.saturated_fat_g::numeric, d.fiber_g::numeric, d.sugar_g::numeric, d.sodium_mg::numeric, d.source
from ins join data d using (source_ref);
