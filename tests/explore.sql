SET NOCOUNT ON;
PRINT '--- 1. DimSite: baris vs nama unik';
SELECT COUNT(*) AS baris_dimsite, COUNT(DISTINCT site_name) AS site_name_unik FROM dim.DimSite;
PRINT '--- 2. Fakta: baris vs id sumber unik';
SELECT 'FactEquipmentUsage' AS tabel, COUNT(*) AS baris, COUNT(DISTINCT equipment_usage_id) AS id_unik FROM fact.FactEquipmentUsage
UNION ALL SELECT 'FactProduction', COUNT(*), COUNT(DISTINCT production_id) FROM fact.FactProduction
UNION ALL SELECT 'FactFinancialTransaction', COUNT(*), COUNT(DISTINCT transaction_id) FROM fact.FactFinancialTransaction;
PRINT '--- 3. Produksi per material_type';
SELECT m.material_type, SUM(p.produced_volume) AS sum_produced_volume, SUM(p.material_quantity) AS sum_material_quantity
FROM fact.FactProduction p JOIN dim.DimMaterial m ON p.material_key = m.material_key
GROUP BY m.material_type;
PRINT '--- 4. Efisiensi';
SELECT AVG(efficiency_ratio) * 100 AS avg_efisiensi_pct,
       SUM(operating_hours) * 100.0 / NULLIF(SUM(operating_hours + downtime_hours), 0) AS rasio_jumlah_pct
FROM fact.FactEquipmentUsage;
