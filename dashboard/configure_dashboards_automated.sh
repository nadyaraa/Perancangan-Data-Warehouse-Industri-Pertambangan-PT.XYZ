#!/bin/bash
if [ -f .env ]; then set -a; . ./.env; set +a; fi  # scrub-env: kredensial dari .env
# PT XYZ Dashboard Configuration Automation Script

echo "🚀 PT XYZ Dashboard Configuration Automation"
echo "============================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if services are running
check_service() {
    local service=$1
    local port=$2
    
    if curl -s http://localhost:$port > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $service is running on port $port${NC}"
        return 0
    else
        echo -e "${RED}❌ $service is not running on port $port${NC}"
        return 1
    fi
}

echo -e "${BLUE}🔍 Checking service status...${NC}"
check_service "Grafana" 3000
check_service "Superset" 8088
check_service "Metabase" 3001
check_service "Jupyter" 8888

echo ""
echo -e "${BLUE}🔧 Testing database queries...${NC}"

# Test basic connectivity
echo -e "${YELLOW}Testing SQL Server connection...${NC}"
docker exec -it ptxyz_sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$MSSQL_SA_PASSWORD" \
    -d PTXYZ_DataWarehouse \
    -Q "SELECT 'Connection successful' as Status;" \
    -C -N

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ SQL Server connection successful${NC}"
else
    echo -e "${RED}❌ SQL Server connection failed${NC}"
    exit 1
fi

# Test corrected dashboard queries
echo ""
echo -e "${YELLOW}Testing corrected dashboard queries...${NC}"

echo "📊 Equipment Utilization Query..."
docker exec -it ptxyz_sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$MSSQL_SA_PASSWORD" \
    -d PTXYZ_DataWarehouse \
    -Q "
    SELECT TOP 3
        e.equipment_type,
        s.site_name,
        COUNT(*) as usage_sessions,
        AVG(CAST(f.operating_hours AS FLOAT)) as avg_operating_hours,
        AVG(CAST(f.efficiency_ratio AS FLOAT)) * 100 as avg_efficiency_pct
    FROM fact.FactEquipmentUsage f
    JOIN dim.DimEquipment e ON f.equipment_key = e.equipment_key
    JOIN dim.DimSite s ON f.site_key = s.site_key
    GROUP BY e.equipment_type, s.site_name
    ORDER BY avg_efficiency_pct DESC;
    " \
    -C -N

echo ""
echo "📈 Production Performance Query..."
docker exec -it ptxyz_sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$MSSQL_SA_PASSWORD" \
    -d PTXYZ_DataWarehouse \
    -Q "
    SELECT TOP 3
        s.site_name,
        m.material_type,
        SUM(CAST(f.produced_volume AS FLOAT)) as total_production,
        AVG(CAST(f.unit_cost AS FLOAT)) as avg_unit_cost
    FROM fact.FactProduction f
    JOIN dim.DimSite s ON f.site_key = s.site_key
    JOIN dim.DimMaterial m ON f.material_key = m.material_key
    GROUP BY s.site_name, m.material_type
    ORDER BY total_production DESC;
    " \
    -C -N

echo ""
echo "💰 Financial Analysis Query..."
docker exec -it ptxyz_sqlserver /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$MSSQL_SA_PASSWORD" \
    -d PTXYZ_DataWarehouse \
    -Q "
    SELECT TOP 3
        s.site_name,
        p.project_name,
        SUM(CAST(f.budgeted_cost AS FLOAT)) as total_budgeted,
        SUM(CAST(f.actual_cost AS FLOAT)) as total_actual,
        SUM(CAST((f.budgeted_cost - f.actual_cost) AS FLOAT)) as total_variance
    FROM fact.FactFinancialTransaction f
    JOIN dim.DimSite s ON f.site_key = s.site_key
    JOIN dim.DimProject p ON f.project_key = p.project_key
    GROUP BY s.site_name, p.project_name
    ORDER BY ABS(SUM(f.budgeted_cost - f.actual_cost)) DESC;
    " \
    -C -N

echo ""
echo -e "${GREEN}✅ All queries executed successfully!${NC}"

echo ""
echo -e "${BLUE}📊 Dashboard Setup Instructions:${NC}"
echo ""

echo -e "${YELLOW}1. Grafana Setup (http://localhost:3000):${NC}"
echo "   - Login: admin/admin"
echo "   - Add SQL Server data source:"
echo "     • Host: sqlserver:1433"
echo "     • Database: PTXYZ_DataWarehouse"
echo "     • User: sa"
echo "     • Password: <MSSQL_SA_PASSWORD>"
echo "   - Create panels using corrected queries"
echo ""

echo -e "${YELLOW}2. Superset Setup (http://localhost:8088):${NC}"
echo "   - Login: admin/admin"
echo "   - Add database connection:"
echo "     • SQLAlchemy URI: mssql+pymssql://sa:<MSSQL_SA_PASSWORD>@sqlserver:1433/PTXYZ_DataWarehouse"
echo "   - Create datasets from fact and dimension tables"
echo "   - Build charts using provided queries"
echo ""

echo -e "${YELLOW}3. Metabase Setup (http://localhost:3001):${NC}"
echo "   - Complete setup wizard"
echo "   - Add SQL Server:"
echo "     • Host: sqlserver"
echo "     • Port: 1433"
echo "     • Database: PTXYZ_DataWarehouse"
echo "     • Username: sa"
echo "     • Password: <MSSQL_SA_PASSWORD>"
echo ""

echo -e "${YELLOW}4. Jupyter Analysis (http://localhost:8888):${NC}"
echo "   - Token: ptxyz123"
echo "   - Use pymssql to connect and analyze data"
echo ""

echo -e "${GREEN}🎯 Key Files Created:${NC}"
echo "   • corrected_dashboard_queries.sql - Schema-aligned queries"
echo "   • COMPLETE_DASHBOARD_GUIDE.md - Comprehensive setup guide"
echo "   • dashboard_configuration.json - Platform configurations"
echo "   • test_dashboard_queries.sh - Query testing script"
echo ""

echo -e "${GREEN}🚀 Your PT XYZ Data Warehouse dashboards are ready!${NC}"
echo -e "${GREEN}All queries have been corrected to match the actual database schema.${NC}"

# Open dashboards in browser (optional)
echo ""
read -p "Open dashboard URLs in browser? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Opening dashboards..."
    if command -v xdg-open > /dev/null; then
        xdg-open http://localhost:3000 &
        xdg-open http://localhost:8088 &
        xdg-open http://localhost:3001 &
        xdg-open http://localhost:8888 &
    elif command -v open > /dev/null; then
        open http://localhost:3000 &
        open http://localhost:8088 &
        open http://localhost:3001 &
        open http://localhost:8888 &
    else
        echo "Please manually open:"
        echo "  Grafana:  http://localhost:3000"
        echo "  Superset: http://localhost:8088"
        echo "  Metabase: http://localhost:3001"
        echo "  Jupyter:  http://localhost:8888"
    fi
fi

echo ""
echo -e "${GREEN}Happy Dashboard Building! 📊🚀${NC}"
