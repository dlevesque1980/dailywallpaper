import 'package:flutter/material.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_preferences.dart';

/// Script de test pour réinitialiser et tester le smart crop
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔄 Réinitialisation des paramètres smart crop...');
  
  // Réinitialiser aux nouveaux paramètres par défaut (agressifs)
  await SmartCropPreferences.resetToDefaults();
  
  // Vider le cache pour forcer le retraitement
  final deletedEntries = await SmartCropPreferences.clearCropCache();
  print('🗑️ Cache vidé: $deletedEntries entrées supprimées');
  
  // Afficher les nouveaux paramètres
  final settings = await SmartCropPreferences.getCropSettings();
  print('⚙️ Nouveaux paramètres:');
  print('   - Agressivité: ${settings.aggressiveness}');
  print('   - Rule of thirds: ${settings.enableRuleOfThirds}');
  print('   - Analyse entropie: ${settings.enableEntropyAnalysis}');
  print('   - Détection contours: ${settings.enableEdgeDetection}');
  print('   - Pondération centre: ${settings.enableCenterWeighting}');
  
  print('✅ Smart crop configuré en mode agressif!');
  print('🚀 Relancez l\'app pour voir la différence');
}