library dailywallpaper.consts;

const String sp_IncludeLockWallpaper = "includelockwallpaper";
const String sp_BingRegion = "bingregion";
const String sp_PexelsCategories = "pexelscategories";
const String sp_NASAEnabled = "nasaenabled";

// Smart Crop Settings
const String sp_SmartCropEnabled = "smartcropenabled";
const String sp_SmartCropAggressiveness = "smartcropaggressiveness";
const String sp_SmartCropRuleOfThirds = "smartcropruleofthirds";
const String sp_SmartCropEntropyAnalysis = "smartcropentropyanalysis";
const String sp_SmartCropEdgeDetection = "smartcropedgedetection";
const String sp_SmartCropCenterWeighting = "smartcropcenterweighting";
const String sp_SmartCropMaxProcessingTime = "smartcropmaxprocessingtime";

// Popular Pexels categories for wallpapers - optimized for smart crop visibility
const List<String> defaultPexelsCategories = [
  "portrait", // Images avec sujets centrés - bon pour smart crop
  "people",   // Visages et personnes - excellent pour smart crop
  "animals",  // Animaux - très bon pour la détection de sujets
  "flowers",  // Détails intéressants pour l'analyse d'entropie
  "architecture", // Lignes et structures pour rule of thirds
  "city",     // Scènes complexes avec points d'intérêt
  "landscape", 
  "nature",
  "abstract", // Formes et couleurs pour l'analyse
  "minimal"   // Compositions simples mais efficaces
];
