import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  base: '/apps/skein/',
  plugins: [viteSingleFile()],
  build: {
    outDir: 'dist',
    modulePreload: false,
  },
  server: {
    proxy: {
      '/apps/skein/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
});
