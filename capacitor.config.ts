import { CapacitorConfig } from '@capacitor/core';

const isDevelopment = process.env.NODE_ENV === 'development';

const config: CapacitorConfig = {
  appId: 'com.pimcil.shop',
  appName: 'Pimcil',
  webDir: 'dist',
  // Only include server config in development for hot reload
  ...(isDevelopment && {
    server: {
      url: 'https://shop.pimcil.com?forceHideBadge=true',
      cleartext: true
    },
  }),
    // iOS specific configuration
  ios: {
    scheme: 'Pimcil',
    contentInset: 'automatic'
  },

  // Android specific configuration  
  android: {
    scheme: 'https',
    allowMixedContent: true,
    captureInput: true
  },

  plugins: {
    Camera: {
      permissions: ['camera']
    },
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert']
    },
    // Firebase messaging configuration for native platforms
    FirebaseMessaging: {
      // Enable automatic initialization
      autoRegister: false
    }
  }
};

export default config;