import pandas as pd

df = pd.read_csv('/Users/anoshpshroff/capstone_app/assets/data/usda_nutrition_database_300k.csv')
df_slim = df[['food_name', 'energy_kcal', 'protein_g', 'fat_g', 'carbs_g', 'fiber_g']].copy()
df_slim.to_csv('/Users/anoshpshroff/capstone_app/assets/data/usda_slim.csv', index=False)
