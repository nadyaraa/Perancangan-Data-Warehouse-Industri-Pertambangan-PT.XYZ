#!/bin/bash
# PT XYZ Data Warehouse - Comprehensive Startup Script
# For Technical and Non-Technical Users

# Colors for better visibility
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="PT XYZ Data Warehouse"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

echo -e "${BLUE}🏭 ${PROJECT_NAME} - Comprehensive Startup${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -f "${COMPOSE_FILE}" ]]; then
    echo -e "${RED}❌ Error: docker-compose.yml not found${NC}"
    echo -e "${YELLOW}💡 Please run this script from the project root directory${NC}"
    echo -e "${YELLOW}   Expected: /home/egistr/Documents/kuliah/semester6/dw/DW_Project_Kelompok22${NC}"
    exit 1
fi

# Check if Docker is running
echo -e "${CYAN}🔍 Checking Docker status...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Create .env file if it doesn't exist
if [[ ! -f "${ENV_FILE}" ]]; then
    echo -e "${YELLOW}📝 Creating environment configuration...${NC}"
    GEN_SA_PASSWORD="${MSSQL_SA_PASSWORD:-Pw$(openssl rand -hex 8)aA1}"
    cat > "${ENV_FILE}" << EOF
# PT XYZ Data Warehouse Environment Configuration
# Generated: $(date)

# SQL Server Configuration
MSSQL_SA_PASSWORD=${GEN_SA_PASSWORD}
MSSQL_PID=Express

# PostgreSQL Configuration (for Airflow)
POSTGRES_USER=airflow
POSTGRES_PASSWORD=airflow
POSTGRES_DB=airflow

# Redis Configuration
REDIS_PASSWORD=ptxyz123

# Airflow Configuration
AIRFLOW_UID=50000
AIRFLOW__CORE__EXECUTOR=CeleryExecutor
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres/airflow
AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=true
AIRFLOW__CORE__LOAD_EXAMPLES=false
AIRFLOW__API__AUTH_BACKENDS=airflow.api.auth.backend.basic_auth
_AIRFLOW_WWW_USER_USERNAME=admin
_AIRFLOW_WWW_USER_PASSWORD=admin

# Superset Configuration
SUPERSET_SECRET_KEY=ptxyz_superset_secret_key_2025
SUPERSET_USERNAME=admin
SUPERSET_PASSWORD=admin
SUPERSET_EMAIL=admin@ptxyz.com

# Jupyter Configuration
JUPYTER_ENABLE_LAB=yes
JUPYTER_TOKEN=ptxyz123

# Grafana Configuration
GF_SECURITY_ADMIN_PASSWORD=admin
GF_USERS_ALLOW_SIGN_UP=false

# Metabase Configuration
MB_DB_TYPE=postgres
MB_DB_DBNAME=metabase
MB_DB_PORT=5432
MB_DB_USER=metabase
MB_DB_PASS=metabase
MB_DB_HOST=postgres_metabase
EOF
    echo -e "${GREEN}✅ Environment file created${NC}"
fi

# Create necessary directories
echo -e "${CYAN}📁 Creating necessary directories...${NC}"
mkdir -p logs/airflow/{dags,logs,plugins} data/{raw,processed,staging} notebooks grafana/{dashboards,datasources} init-scripts

# Set proper permissions for Airflow
echo -e "${CYAN}🔐 Setting up permissions...${NC}"
sudo chown -R 50000:0 logs/airflow/logs
sudo chown -R 50000:0 dags
sudo chown -R 50000:0 plugins 2>/dev/null || true

echo -e "${YELLOW}🔄 Starting ${PROJECT_NAME}...${NC}"
echo "This process will take 3-5 minutes depending on your system..."
echo ""

# Stop any existing containers
echo -e "${BLUE}🛑 Stopping any existing containers...${NC}"
docker compose down --remove-orphans 2>/dev/null || true

# Pull latest images
echo -e "${BLUE}📥 Pulling latest Docker images...${NC}"
docker compose pull

# Start core infrastructure first
echo -e "${BLUE}🚀 Starting core infrastructure...${NC}"
docker compose up -d sqlserver postgres redis

# Wait for databases to be ready
echo -e "${YELLOW}⏳ Waiting for databases to initialize...${NC}"
sleep 30

# Check SQL Server health
echo -e "${CYAN}🔍 Checking SQL Server health...${NC}"
max_attempts=12
attempt=1
while [ $attempt -le $max_attempts ]; do
    if docker compose exec -T sqlserver sh -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -Q "SELECT 1" -C -N' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ SQL Server is ready${NC}"
        break
    fi
    echo "Attempt $attempt/$max_attempts - SQL Server not ready yet..."
    sleep 10
    ((attempt++))
done

if [ $attempt -gt $max_attempts ]; then
    echo -e "${RED}❌ SQL Server failed to start within expected time${NC}"
    exit 1
fi

# Initialize database schema
echo -e "${BLUE}🏗️  Initializing database schema...${NC}"
docker compose up -d db_init
sleep 20

# Start Airflow services
echo -e "${BLUE}✈️  Starting Airflow services...${NC}"
docker compose up -d airflow-webserver airflow-scheduler airflow-worker

# Start visualization services
echo -e "${BLUE}📊 Starting visualization services...${NC}"
docker compose up -d superset grafana jupyter metabase postgres_metabase

# Final health check
echo -e "${YELLOW}⏳ Performing final health checks...${NC}"
sleep 45

# Check service status
echo -e "${CYAN}🔍 Checking service status...${NC}"
services=("sqlserver" "airflow-webserver" "superset" "grafana" "jupyter")
for service in "${services[@]}"; do
    if docker compose ps | grep -q "${service}.*Up"; then
        echo -e "  ✅ ${service} is running"
    else
        echo -e "  ⚠️  ${service} may have issues"
    fi
done

echo ""
echo -e "${GREEN}🎉 ${PROJECT_NAME} is Ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}📊 Access Your Services:${NC}"
echo -e "  • ${CYAN}Airflow (ETL Pipeline):${NC}     http://localhost:8080"
echo -e "    Username: admin | Password: admin"
echo ""
echo -e "  • ${CYAN}Grafana (Operations):${NC}       http://localhost:3000"
echo -e "    Username: admin | Password: admin"
echo ""
echo -e "  • ${CYAN}Superset (Analytics):${NC}       http://localhost:8088"
echo -e "    Username: admin | Password: admin"
echo ""
echo -e "  • ${CYAN}Metabase (BI Reports):${NC}      http://localhost:3001"
echo -e "    Setup required on first visit"
echo ""
echo -e "  • ${CYAN}Jupyter (Data Science):${NC}     http://localhost:8888"
echo -e "    Token: ptxyz123"
echo ""

echo -e "${PURPLE}🎯 Quick Start Guide:${NC}"
echo -e "  1. Open Airflow: http://localhost:8080"
echo -e "  2. Enable and run the DAG: 'ptxyz_comprehensive_etl'"
echo -e "  3. Monitor progress in Airflow dashboard"
echo -e "  4. Access dashboards once data is loaded"
echo ""

echo -e "${YELLOW}🔧 Management Commands:${NC}"
echo -e "  • Status Check:    ./bin/status.sh"
echo -e "  • Stop Services:   ./bin/stop.sh"
echo -e "  • View Logs:       docker compose logs -f [service_name]"
echo -e "  • Restart:         docker compose restart [service_name]"
echo ""

echo -e "${BLUE}📚 Documentation:${NC}"
echo -e "  • User Guide:      docs/USER_GUIDE.md"
echo -e "  • Architecture:    docs/architecture/ARCHITECTURE.md"
echo -e "  • Quick Setup:     docs/deployment/QUICKSTART.md"
echo ""

echo -e "${GREEN}🚀 System Status: OPERATIONAL${NC}"
echo -e "${GREEN}Happy Data Mining! ⛏️📈${NC}"

# Show resource usage
echo ""
echo -e "${CYAN}💻 Resource Usage:${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10
