import Foundation

public struct HealthKitNutritionRawData: Equatable, Encodable {
  
  public let sourceBundle: String
  
  // Macros
  public let energyTotal: [LocalQuantitySample]?
  public let carbohydrates: [LocalQuantitySample]?
  public let fiber: [LocalQuantitySample]?
  public let sugar: [LocalQuantitySample]?
  public let fatTotal: [LocalQuantitySample]?
  public let fatMonounsaturated: [LocalQuantitySample]?
  public let fatPolyunsaturated: [LocalQuantitySample]?
  public let fatSaturated: [LocalQuantitySample]?
  public let cholesterol: [LocalQuantitySample]?
  public let protein: [LocalQuantitySample]?
  
  // Vitamins
  public let vitaminA: [LocalQuantitySample]?
  public let vitaminB1: [LocalQuantitySample]?
  public let riboflavin: [LocalQuantitySample]?
  public let niacin: [LocalQuantitySample]?
  public let pantothenicAcid: [LocalQuantitySample]?
  public let vitaminB6: [LocalQuantitySample]?
  public let biotin: [LocalQuantitySample]?
  public let vitaminB12: [LocalQuantitySample]?
  public let vitaminC: [LocalQuantitySample]?
  public let vitaminD: [LocalQuantitySample]?
  public let vitaminE: [LocalQuantitySample]?
  public let vitaminK: [LocalQuantitySample]?
  public let folicAcid: [LocalQuantitySample]?
  
  // Minerals
  public let calcium: [LocalQuantitySample]?
  public let chloride: [LocalQuantitySample]?
  public let iron: [LocalQuantitySample]?
  public let magnesium: [LocalQuantitySample]?
  public let phosphorus: [LocalQuantitySample]?
  public let potassium: [LocalQuantitySample]?
  public let sodium: [LocalQuantitySample]?
  public let zinc: [LocalQuantitySample]?
  
  // Ultra-trace Minerals
  public let chromium: [LocalQuantitySample]?
  public let copper: [LocalQuantitySample]?
  public let iodine: [LocalQuantitySample]?
  public let manganese: [LocalQuantitySample]?
  public let molybdenum: [LocalQuantitySample]?
  public let selenium: [LocalQuantitySample]?
  
  // Hydration & Caffeine
  public let water: [LocalQuantitySample]?
  public let caffeine: [LocalQuantitySample]?
  
  public func dataCount() -> Int {
    let allSamples = [
      energyTotal, carbohydrates, fiber, sugar, fatTotal, fatMonounsaturated,
      fatPolyunsaturated, fatSaturated, cholesterol, protein, vitaminA, vitaminB1,
      riboflavin, niacin, pantothenicAcid, vitaminB6, biotin, vitaminB12, vitaminC,
      vitaminD, vitaminE, vitaminK, folicAcid, calcium, chloride, iron, magnesium,
      phosphorus, potassium, sodium, zinc, chromium, copper, iodine, manganese,
      molybdenum, selenium, water, caffeine
    ]
    
    return allSamples.compactMap { $0?.count }.max() ?? 0
  }
  
  public init(
    sourceBundle: String,
    energyTotal: [LocalQuantitySample]? = nil,
    carbohydrates: [LocalQuantitySample]? = nil,
    fiber: [LocalQuantitySample]? = nil,
    sugar: [LocalQuantitySample]? = nil,
    fatTotal: [LocalQuantitySample]? = nil,
    fatMonounsaturated: [LocalQuantitySample]? = nil,
    fatPolyunsaturated: [LocalQuantitySample]? = nil,
    fatSaturated: [LocalQuantitySample]? = nil,
    cholesterol: [LocalQuantitySample]? = nil,
    protein: [LocalQuantitySample]? = nil,
    vitaminA: [LocalQuantitySample]? = nil,
    vitaminB1: [LocalQuantitySample]? = nil,
    riboflavin: [LocalQuantitySample]? = nil,
    niacin: [LocalQuantitySample]? = nil,
    pantothenicAcid: [LocalQuantitySample]? = nil,
    vitaminB6: [LocalQuantitySample]? = nil,
    biotin: [LocalQuantitySample]? = nil,
    vitaminB12: [LocalQuantitySample]? = nil,
    vitaminC: [LocalQuantitySample]? = nil,
    vitaminD: [LocalQuantitySample]? = nil,
    vitaminE: [LocalQuantitySample]? = nil,
    vitaminK: [LocalQuantitySample]? = nil,
    folicAcid: [LocalQuantitySample]? = nil,
    calcium: [LocalQuantitySample]? = nil,
    chloride: [LocalQuantitySample]? = nil,
    iron: [LocalQuantitySample]? = nil,
    magnesium: [LocalQuantitySample]? = nil,
    phosphorus: [LocalQuantitySample]? = nil,
    potassium: [LocalQuantitySample]? = nil,
    sodium: [LocalQuantitySample]? = nil,
    zinc: [LocalQuantitySample]? = nil,
    chromium: [LocalQuantitySample]? = nil,
    copper: [LocalQuantitySample]? = nil,
    iodine: [LocalQuantitySample]? = nil,
    manganese: [LocalQuantitySample]? = nil,
    molybdenum: [LocalQuantitySample]? = nil,
    selenium: [LocalQuantitySample]? = nil,
    water: [LocalQuantitySample]? = nil,
    caffeine: [LocalQuantitySample]? = nil
  ) {
    self.sourceBundle = sourceBundle
    self.energyTotal = energyTotal
    self.carbohydrates = carbohydrates
    self.fiber = fiber
    self.sugar = sugar
    self.fatTotal = fatTotal
    self.fatMonounsaturated = fatMonounsaturated
    self.fatPolyunsaturated = fatPolyunsaturated
    self.fatSaturated = fatSaturated
    self.cholesterol = cholesterol
    self.protein = protein
    self.vitaminA = vitaminA
    self.vitaminB1 = vitaminB1
    self.riboflavin = riboflavin
    self.niacin = niacin
    self.pantothenicAcid = pantothenicAcid
    self.vitaminB6 = vitaminB6
    self.biotin = biotin
    self.vitaminB12 = vitaminB12
    self.vitaminC = vitaminC
    self.vitaminD = vitaminD
    self.vitaminE = vitaminE
    self.vitaminK = vitaminK
    self.folicAcid = folicAcid
    self.calcium = calcium
    self.chloride = chloride
    self.iron = iron
    self.magnesium = magnesium
    self.phosphorus = phosphorus
    self.potassium = potassium
    self.sodium = sodium
    self.zinc = zinc
    self.chromium = chromium
    self.copper = copper
    self.iodine = iodine
    self.manganese = manganese
    self.molybdenum = molybdenum
    self.selenium = selenium
    self.water = water
    self.caffeine = caffeine
  }
}

public struct ManualMealCreation: Equatable, Encodable{
  public let healthkit: HealthKitNutritionRawData

  public init(healthkit: HealthKitNutritionRawData) {
    self.healthkit = healthkit
  }

  public func dataCount() -> Int {
    return self.healthkit.dataCount()
  }
}

public struct MealPatch: Equatable, Encodable {
  public let meals: [ManualMealCreation]

  public init(meals: [ManualMealCreation]){
    self.meals = meals
  }

  public func dataCount() -> Int {
    return self.meals.reduce(0, {result, meal in result + meal.dataCount()})
  }
}
