/* Conexión con el servidor (Supabase). Ambos valores son públicos por diseño:
   la seguridad está en las reglas de la base de datos (supabase/instalar.sql). */
window.EST_CONFIG = {
  SUPABASE_URL: 'https://wphxtspicejywwzlbuux.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndwaHh0c3BpY2VqeXd3emxidXV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4MjU4OTEsImV4cCI6MjEwNzQwMTg5MX0.coQrJqkMbwHdf-E9IgpQ97T4SHAI8LKao3zZAgcZsko',
  ADMIN_EMAIL: 'juanjosuecastilloloyola@gmail.com',
  MARCA: 'Estaciona',
  AUTOR: 'CodeFix · Josué Castillo',
  VERSION: '1.0.1',
  // Mapa: Santiago por defecto. Teselas de CARTO (sobre OpenStreetMap).
  CENTRO: [-33.4489, -70.6693],
  ZOOM: 12,
  TILES: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
  TILES_OSCURO: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
  TILES_RESPALDO: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ATRIBUCION: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>'
};
