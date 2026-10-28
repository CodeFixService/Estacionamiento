/* Conexión con el servidor (Supabase). Ambos valores son públicos por diseño:
   la seguridad está en las reglas de la base de datos (supabase/instalar.sql). */
window.EST_CONFIG = {
  SUPABASE_URL: 'https://wphxtspicejywwzlbuux.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndwaHh0c3BpY2VqeXd3emxidXV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4MjU4OTEsImV4cCI6MjEwNzQwMTg5MX0.coQrJqkMbwHdf-E9IgpQ97T4SHAI8LKao3zZAgcZsko',
  ADMIN_EMAIL: 'juanjosuecastilloloyola@gmail.com',
  MARCA: 'Estaciona',
  AUTOR: 'CodeFix',
  VERSION: '2.4.1',
  // Mapa: Santiago por defecto. OpenFreeMap (vectorial) y OpenStreetMap de respaldo: gratis y sin API key.
  CENTRO: [-33.4489, -70.6693],
  ZOOM: 12,
  ESTILO: 'https://tiles.openfreemap.org/styles/positron',
  TILES: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ATRIBUCION: '<a href="https://openfreemap.org" target="_blank">OpenFreeMap</a> &copy; <a href="https://www.openmaptiles.org/" target="_blank">OpenMapTiles</a> &copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>'
};
