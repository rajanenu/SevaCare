import { useState } from 'react';
import { ScrollView, StyleSheet, Text, View, Pressable, Platform } from 'react-native';
import { AppShell, PageHeader, PrimaryButton, SecondaryButton } from '../components/ui';
import { useTheme } from '../providers/theme-provider';
import { colorPalettes, type ColorPalette } from '../palettes';
import { type AppScreen, type BottomNavItem } from '../types/app';

const FONT = Platform.select({
  web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
  default: 'System',
}) as string;

export function ColorPaletteScreen({
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
  onPaletteSelect,
}: {
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  onPaletteSelect: (palette: ColorPalette) => void;
}) {
  const theme = useTheme();
  const [selectedPalette, setSelectedPalette] = useState<string | null>(null);

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Color Palettes" subtitle="Choose a vibrant button color scheme" />

      <Text style={[styles.infoText, { color: theme.textMuted }]}>
        Preview different button colors below. The Sign Out button will always remain red.
      </Text>

      <ScrollView
        contentContainerStyle={styles.paletteGrid}
        showsVerticalScrollIndicator={false}
      >
        {colorPalettes.map((palette) => (
          <Pressable
            key={palette.id}
            onPress={() => setSelectedPalette(palette.id)}
            style={[
              styles.paletteCard,
              {
                backgroundColor: theme.card,
                borderColor: selectedPalette === palette.id ? palette.primaryStrong : theme.border,
                borderWidth: selectedPalette === palette.id ? 3 : 1.5,
              },
            ]}
          >
            {/* Palette preview header */}
            <View style={styles.palettePreview}>
              <View
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  backgroundImage: `linear-gradient(135deg, ${palette.buttonGradient[0]} 0%, ${palette.buttonGradient[1]} 100%)`,
                } as any}
              />
              <Text style={styles.palettePreviewText}>Preview</Text>
            </View>

            {/* Palette info */}
            <View style={styles.paletteInfo}>
              <Text style={[styles.paletteName, { color: theme.text }]}>{palette.name}</Text>
              <Text style={[styles.paletteDescription, { color: theme.textMuted }]}>
                {palette.description}
              </Text>
            </View>

            {/* Sample buttons */}
            <View style={styles.buttonSample}>
              <View
                style={[
                  styles.sampleButton,
                  {
                    backgroundColor: palette.primary,
                    borderColor: palette.primaryStrong,
                  },
                ]}
              >
                <Text style={styles.sampleButtonText}>Primary</Text>
              </View>
              <View
                style={[
                  styles.sampleButton,
                  {
                    backgroundColor: palette.primaryStrong,
                    borderColor: palette.primaryStrong,
                  },
                ]}
              >
                <Text style={styles.sampleButtonText}>Strong</Text>
              </View>
            </View>

            {/* Color codes */}
            <View style={styles.colorCodes}>
              <View style={styles.colorCode}>
                <Text style={[styles.colorLabel, { color: theme.textMuted }]}>Primary:</Text>
                <Text style={[styles.colorValue, { color: theme.text, fontWeight: '600' }]}>
                  {palette.primary}
                </Text>
              </View>
              <View style={styles.colorCode}>
                <Text style={[styles.colorLabel, { color: theme.textMuted }]}>Strong:</Text>
                <Text style={[styles.colorValue, { color: theme.text, fontWeight: '600' }]}>
                  {palette.primaryStrong}
                </Text>
              </View>
            </View>
          </Pressable>
        ))}
      </ScrollView>

      {/* Action buttons */}
      <View style={styles.actionRow}>
        <SecondaryButton label="Cancel" onPress={() => onNavigate('settings')} />
        <PrimaryButton
          label={selectedPalette ? 'Apply Colors' : 'Select a palette'}
          onPress={() => {
            if (selectedPalette) {
              const palette = colorPalettes.find((p) => p.id === selectedPalette);
              if (palette) {
                onPaletteSelect(palette);
                onNavigate('settings');
              }
            }
          }}
        />
      </View>
    </AppShell>
  );
}

const styles = StyleSheet.create({
  infoText: {
    fontFamily: FONT,
    fontSize: 14,
    marginBottom: 20,
    lineHeight: 20,
  },
  paletteGrid: {
    gap: 16,
    paddingBottom: 20,
  },
  paletteCard: {
    borderRadius: 14,
    overflow: 'hidden',
    gap: 12,
  },
  palettePreview: {
    height: 80,
    justifyContent: 'center',
    alignItems: 'center',
  },
  palettePreviewText: {
    fontFamily: FONT,
    fontSize: 16,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  paletteInfo: {
    paddingHorizontal: 14,
    gap: 4,
  },
  paletteName: {
    fontFamily: FONT,
    fontSize: 16,
    fontWeight: '700',
  },
  paletteDescription: {
    fontFamily: FONT,
    fontSize: 13,
  },
  buttonSample: {
    flexDirection: 'row',
    gap: 10,
    paddingHorizontal: 14,
    justifyContent: 'center',
  },
  sampleButton: {
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 999,
    borderWidth: 1,
  },
  sampleButtonText: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '600',
    color: '#FFFFFF',
    textAlign: 'center',
    lineHeight: 16,
    includeFontPadding: false,
  },
  colorCodes: {
    paddingHorizontal: 14,
    paddingBottom: 14,
    gap: 8,
  },
  colorCode: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  colorLabel: {
    fontFamily: FONT,
    fontSize: 12,
  },
  colorValue: {
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: '600',
  },
  actionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    gap: 12,
    marginTop: 20,
  },
});
