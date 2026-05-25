-- Seed data for Recipe Cookbook Database

-- Insert sample ingredients
INSERT INTO ingredients (name) VALUES ('Spaghetti');
INSERT INTO ingredients (name) VALUES ('Eggs');
INSERT INTO ingredients (name) VALUES ('Pancetta');
INSERT INTO ingredients (name) VALUES ('Parmesan Cheese');
INSERT INTO ingredients (name) VALUES ('Black Pepper');
INSERT INTO ingredients (name) VALUES ('Salt');
INSERT INTO ingredients (name) VALUES ('Chicken Breast');
INSERT INTO ingredients (name) VALUES ('Breadcrumbs');
INSERT INTO ingredients (name) VALUES ('Mozzarella Cheese');
INSERT INTO ingredients (name) VALUES ('Tomato Sauce');
INSERT INTO ingredients (name) VALUES ('Olive Oil');
INSERT INTO ingredients (name) VALUES ('Garlic');
INSERT INTO ingredients (name) VALUES ('Penne Pasta');
INSERT INTO ingredients (name) VALUES ('Bell Peppers');
INSERT INTO ingredients (name) VALUES ('Zucchini');
INSERT INTO ingredients (name) VALUES ('Cherry Tomatoes');
INSERT INTO ingredients (name) VALUES ('Basil');
INSERT INTO ingredients (name) VALUES ('Butter');
INSERT INTO ingredients (name) VALUES ('Flour');
INSERT INTO ingredients (name) VALUES ('Salmon Fillet');
INSERT INTO ingredients (name) VALUES ('Lemon');
INSERT INTO ingredients (name) VALUES ('Dill');

-- Insert sample tags
INSERT INTO tags (name) VALUES ('Italian');
INSERT INTO tags (name) VALUES ('Pasta');
INSERT INTO tags (name) VALUES ('Quick');
INSERT INTO tags (name) VALUES ('Easy');
INSERT INTO tags (name) VALUES ('Vegetarian');
INSERT INTO tags (name) VALUES ('Chicken');
INSERT INTO tags (name) VALUES ('Seafood');
INSERT INTO tags (name) VALUES ('Healthy');
INSERT INTO tags (name) VALUES ('Comfort Food');

-- Insert sample recipes
INSERT INTO recipes (title, time_minutes, price, description, image) 
VALUES (
    'Spaghetti Carbonara',
    25,
    '12.50',
    'Step 1: Bring a large pot of salted water to boil and cook 400g spaghetti according to package directions.

Step 2: While pasta cooks, cut 200g pancetta into small cubes and fry in a large pan over medium heat until crispy (about 5 minutes).

Step 3: In a bowl, whisk together 4 large eggs, 100g grated Parmesan cheese, and plenty of black pepper.

Step 4: When pasta is ready, reserve 1 cup of pasta water, then drain the pasta.

Step 5: Remove the pan with pancetta from heat. Add the hot pasta to the pan and toss.

Step 6: Pour the egg mixture over the pasta and toss quickly. The heat from the pasta will cook the eggs. Add pasta water bit by bit if needed to create a creamy sauce.

Step 7: Serve immediately with extra Parmesan cheese and black pepper.',
    'https://images.unsplash.com/photo-1612874742237-6526221588e3?w=400'
);

INSERT INTO recipes (title, time_minutes, price, description, image)
VALUES (
    'Chicken Parmesan',
    50,
    '18.00',
    'Step 1: Preheat oven to 200C (400F).

Step 2: Place 2 chicken breasts between plastic wrap and pound to 2cm thickness.

Step 3: Set up breading station: flour in one plate, 2 beaten eggs in another, and 150g breadcrumbs mixed with 50g Parmesan in a third.

Step 4: Season chicken with salt and pepper, then coat in flour, dip in egg, and press into breadcrumb mixture.

Step 5: Heat 3 tablespoons olive oil in a large oven-safe skillet over medium-high heat. Fry chicken until golden brown, about 4 minutes per side.

Step 6: Pour 300ml tomato sauce over the chicken, then top each breast with 100g sliced mozzarella.

Step 7: Transfer skillet to oven and bake for 15-20 minutes until cheese is melted and bubbly.

Step 8: Garnish with fresh basil and serve with pasta or salad.',
    'https://images.unsplash.com/photo-1632778149955-e80f8ceca2e8?w=400'
);

INSERT INTO recipes (title, time_minutes, price, description, image)
VALUES (
    'Pasta Primavera',
    30,
    '10.00',
    'Step 1: Cook 350g penne pasta in salted boiling water according to package directions. Reserve 1 cup pasta water before draining.

Step 2: While pasta cooks, chop 1 red bell pepper, 1 zucchini into bite-sized pieces, and halve 200g cherry tomatoes.

Step 3: Heat 3 tablespoons olive oil in a large pan over medium-high heat. Add 3 minced garlic cloves and cook for 30 seconds.

Step 4: Add bell peppers and zucchini to the pan. Cook for 5-7 minutes until vegetables are tender.

Step 5: Add cherry tomatoes and cook for another 2-3 minutes until they start to soften.

Step 6: Add the drained pasta to the pan with vegetables. Toss everything together, adding pasta water as needed to create a light sauce.

Step 7: Season with salt and black pepper. Remove from heat and stir in fresh basil leaves.

Step 8: Serve hot with grated Parmesan cheese on top.',
    'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=400'
);

INSERT INTO recipes (title, time_minutes, price, description, image)
VALUES (
    'Garlic Butter Salmon',
    20,
    '22.00',
    'Step 1: Pat 4 salmon fillets (150g each) dry with paper towels and season both sides with salt and pepper.

Step 2: Heat 2 tablespoons olive oil in a large skillet over medium-high heat.

Step 3: Place salmon fillets skin-side up in the pan. Cook for 4-5 minutes until golden brown.

Step 4: Flip the salmon and cook for another 3-4 minutes.

Step 5: Reduce heat to medium and add 3 tablespoons butter, 4 minced garlic cloves, and juice of 1 lemon to the pan.

Step 6: Spoon the garlic butter sauce over the salmon repeatedly for 1-2 minutes.

Step 7: Remove from heat and sprinkle with fresh dill.

Step 8: Serve immediately with the pan sauce, accompanied by rice or vegetables.',
    'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=400'
);

-- Link recipes to ingredients (recipe_id, ingredient_id, amount, unit)
-- Recipe 1: Spaghetti Carbonara
INSERT INTO recipe_ingredients VALUES (1, 1, '400', 'g');    -- Spaghetti
INSERT INTO recipe_ingredients VALUES (1, 2, '4', 'pieces'); -- Eggs
INSERT INTO recipe_ingredients VALUES (1, 3, '200', 'g');    -- Pancetta
INSERT INTO recipe_ingredients VALUES (1, 4, '100', 'g');    -- Parmesan Cheese
INSERT INTO recipe_ingredients VALUES (1, 5, '1', 'tsp');    -- Black Pepper
INSERT INTO recipe_ingredients VALUES (1, 6, '1', 'tsp');    -- Salt

-- Recipe 2: Chicken Parmesan
INSERT INTO recipe_ingredients VALUES (2, 7, '2', 'pieces'); -- Chicken Breast
INSERT INTO recipe_ingredients VALUES (2, 8, '1', 'cup');    -- Breadcrumbs
INSERT INTO recipe_ingredients VALUES (2, 9, '200', 'g');    -- Mozzarella Cheese
INSERT INTO recipe_ingredients VALUES (2, 10, '2', 'cups');  -- Tomato Sauce
INSERT INTO recipe_ingredients VALUES (2, 11, '3', 'tbsp');  -- Olive Oil
INSERT INTO recipe_ingredients VALUES (2, 4, '50', 'g');     -- Parmesan Cheese

-- Recipe 3: Vegetarian Penne Primavera
INSERT INTO recipe_ingredients VALUES (3, 13, '300', 'g');   -- Penne Pasta
INSERT INTO recipe_ingredients VALUES (3, 14, '2', 'pieces'); -- Bell Peppers
INSERT INTO recipe_ingredients VALUES (3, 15, '1', 'piece'); -- Zucchini
INSERT INTO recipe_ingredients VALUES (3, 16, '200', 'g');   -- Cherry Tomatoes
INSERT INTO recipe_ingredients VALUES (3, 12, '4', 'cloves'); -- Garlic
INSERT INTO recipe_ingredients VALUES (3, 11, '4', 'tbsp');  -- Olive Oil
INSERT INTO recipe_ingredients VALUES (3, 17, '1', 'handful'); -- Basil

-- Recipe 4: Grilled Salmon
INSERT INTO recipe_ingredients VALUES (4, 20, '2', 'pieces'); -- Salmon Fillet
INSERT INTO recipe_ingredients VALUES (4, 21, '1', 'piece');  -- Lemon
INSERT INTO recipe_ingredients VALUES (4, 22, '2', 'tbsp');   -- Dill
INSERT INTO recipe_ingredients VALUES (4, 18, '3', 'tbsp');   -- Butter
INSERT INTO recipe_ingredients VALUES (4, 6, '1', 'tsp');     -- Salt
INSERT INTO recipe_ingredients VALUES (4, 5, '1/2', 'tsp');   -- Black Pepper

-- Link recipes to tags
INSERT INTO recipe_tags VALUES (1, 1); -- Carbonara: Italian
INSERT INTO recipe_tags VALUES (1, 2); -- Carbonara: Pasta
INSERT INTO recipe_tags VALUES (1, 3); -- Carbonara: Quick

INSERT INTO recipe_tags VALUES (2, 1); -- Chicken Parmesan: Italian
INSERT INTO recipe_tags VALUES (2, 6); -- Chicken Parmesan: Chicken
INSERT INTO recipe_tags VALUES (2, 9); -- Chicken Parmesan: Comfort Food

INSERT INTO recipe_tags VALUES (3, 2); -- Primavera: Pasta
INSERT INTO recipe_tags VALUES (3, 3); -- Primavera: Quick
INSERT INTO recipe_tags VALUES (3, 4); -- Primavera: Easy
INSERT INTO recipe_tags VALUES (3, 5); -- Primavera: Vegetarian
INSERT INTO recipe_tags VALUES (3, 8); -- Primavera: Healthy

INSERT INTO recipe_tags VALUES (4, 7); -- Salmon: Seafood
INSERT INTO recipe_tags VALUES (4, 3); -- Salmon: Quick
INSERT INTO recipe_tags VALUES (4, 8); -- Salmon: Healthy
