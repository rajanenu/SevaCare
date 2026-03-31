// Vibrant color palettes for button selection
export type ColorPalette = {
  id: string;
  name: string;
  description: string;
  primary: string;
  primaryStrong: string;
  shadowColor: string;
  buttonGradient: [string, string];
};

export const colorPalettes: ColorPalette[] = [
  {
    id: 'ocean-blue',
    name: 'Ocean Blue',
    description: 'Deep, vibrant blue with strong presence',
    primary: '#0EA5E9',
    primaryStrong: '#0284C7',
    shadowColor: '#0284C7',
    buttonGradient: ['#38BDF8', '#0EA5E9'],
  },
  {
    id: 'vivid-purple',
    name: 'Vivid Purple',
    description: 'Rich purple with dynamic flair',
    primary: '#A855F7',
    primaryStrong: '#9333EA',
    shadowColor: '#9333EA',
    buttonGradient: ['#D8B4FE', '#A855F7'],
  },
  {
    id: 'emerald-green',
    name: 'Emerald Green',
    description: 'Vibrant green with natural energy',
    primary: '#10B981',
    primaryStrong: '#059669',
    shadowColor: '#059669',
    buttonGradient: ['#6EE7B7', '#10B981'],
  },
  {
    id: 'sunset-orange',
    name: 'Sunset Orange',
    description: 'Warm, vibrant orange energy',
    primary: '#FB923C',
    primaryStrong: '#EA580C',
    shadowColor: '#EA580C',
    buttonGradient: ['#FDBA74', '#FB923C'],
  },
  {
    id: 'coral-pink',
    name: 'Coral Pink',
    description: 'Vibrant coral with modern touch',
    primary: '#F43F5E',
    primaryStrong: '#E11D48',
    shadowColor: '#E11D48',
    buttonGradient: ['#FB7185', '#F43F5E'],
  },
  {
    id: 'golden-yellow',
    name: 'Golden Yellow',
    description: 'Luminous yellow with premium feel',
    primary: '#FBBF24',
    primaryStrong: '#F59E0B',
    shadowColor: '#F59E0B',
    buttonGradient: ['#FCD34D', '#FBBF24'],
  },
  {
    id: 'indigo-royale',
    name: 'Indigo Royale',
    description: 'Deep indigo with royal essence',
    primary: '#6366F1',
    primaryStrong: '#4F46E5',
    shadowColor: '#4F46E5',
    buttonGradient: ['#A5B4FC', '#6366F1'],
  },
  {
    id: 'rose-pink',
    name: 'Rose Pink',
    description: 'Elegant rose with modern vibrancy',
    primary: '#EC4899',
    primaryStrong: '#DB2777',
    shadowColor: '#DB2777',
    buttonGradient: ['#F472B6', '#EC4899'],
  },
];
