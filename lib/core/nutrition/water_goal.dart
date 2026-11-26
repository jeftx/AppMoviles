/// Estima vasos completos de 250 ml con la fórmula peso (kg) / 7.
int dailyWaterGlasses(double weightKg) {
  if (!weightKg.isFinite || weightKg <= 0) return 0;
  return (weightKg / 7).ceil();
}

int dailyWaterGoalMl(double weightKg) => dailyWaterGlasses(weightKg) * 250;
