---
name: az-database-update
description: Execute SQL queries against Azure SQL databases. Use for database migrations, user management, data updates, or ad-hoc queries on Azure SQL.
allowed-tools: Bash, Read, Write, Glob
---

# Azure SQL Database Update Workflow

Execute SQL queries against Azure SQL databases using Azure CLI authentication.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- .NET SDK installed (for running the query script)
- Appropriate Azure subscription access

## Process

### 1. Identify the Target Database

First, determine which subscription and database to target.

#### List subscriptions:
```bash
az account list --query "[].{name:name, id:id, isDefault:isDefault}" -o table
```

#### Switch subscription if needed:
```bash
az account set --subscription "SUBSCRIPTION_NAME"
```

#### List SQL servers in current subscription:
```bash
az sql server list --query "[].{name:name, resourceGroup:resourceGroup, fqdn:fullyQualifiedDomainName}" -o table
```

#### List databases on a server:
```bash
az sql db list --server SERVER_NAME --resource-group RESOURCE_GROUP --query "[].name" -o table
```

### 2. Configure Access

#### Add temporary firewall rule for your IP:
```bash
MY_IP=$(curl -s ifconfig.me)
az sql server firewall-rule create \
  --server SERVER_NAME \
  --resource-group RESOURCE_GROUP \
  --name "TempClaude" \
  --start-ip-address $MY_IP \
  --end-ip-address $MY_IP \
  -o table
```

#### Set yourself as AD admin (if not already set):
```bash
# Check current AD admin
az sql server ad-admin list --server SERVER_NAME --resource-group RESOURCE_GROUP -o table

# Get your user ID
USER_ID=$(az ad signed-in-user show --query "id" -o tsv)

# Set yourself as AD admin
az sql server ad-admin create \
  --server SERVER_NAME \
  --resource-group RESOURCE_GROUP \
  --display-name "YOUR_NAME" \
  --object-id $USER_ID \
  -o table
```

### 3. Create and Run the Query Script

Create a .NET console app to execute the query:

```bash
cd /tmp && rm -rf AzureSqlQuery && dotnet new console -n AzureSqlQuery -o AzureSqlQuery --force
cd /tmp/AzureSqlQuery && dotnet add package Microsoft.Data.SqlClient && dotnet add package Azure.Identity
```

Write the Program.cs with your query:

```csharp
using Azure.Identity;
using Microsoft.Data.SqlClient;

var connectionString = "Server=tcp:SERVER_NAME.database.windows.net,1433;Initial Catalog=DATABASE_NAME;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;";

var credential = new AzureCliCredential();
var token = await credential.GetTokenAsync(new Azure.Core.TokenRequestContext(["https://database.windows.net/.default"]));

using var connection = new SqlConnection(connectionString);
connection.AccessToken = token.Token;
await connection.OpenAsync();
Console.WriteLine("Connected to database");

// YOUR QUERY HERE
// Example SELECT:
var cmd = new SqlCommand("SELECT * FROM Users WHERE Email = 'user@example.com'", connection);
using var reader = await cmd.ExecuteReaderAsync();
while (await reader.ReadAsync())
{
    Console.WriteLine($"Found: {reader.GetValue(0)}");
}

// Example UPDATE/DELETE (use ExecuteNonQueryAsync):
// var cmd = new SqlCommand("DELETE FROM Users WHERE Email = 'user@example.com'", connection);
// var rowsAffected = await cmd.ExecuteNonQueryAsync();
// Console.WriteLine($"Affected {rowsAffected} row(s)");
```

Run the script:
```bash
cd /tmp/AzureSqlQuery && dotnet run
```

### 4. Cleanup

**Always clean up the temporary firewall rule:**
```bash
az sql server firewall-rule delete \
  --server SERVER_NAME \
  --resource-group RESOURCE_GROUP \
  --name "TempClaude"
```

## Common Queries

### List all users:
```sql
SELECT Id, Email, Role FROM Users
```

### Delete a user by email:
```sql
DELETE FROM Users WHERE Email = 'user@example.com'
```

### Update a user's role:
```sql
UPDATE Users SET Role = 'Admin' WHERE Email = 'user@example.com'
```

### Check table schema:
```sql
SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Users'
```

## Troubleshooting

### "Login failed for user '<token-identified principal>'"
- You need to set yourself as AD admin on the SQL server
- Run the `az sql server ad-admin create` command from step 2

### "Cannot open server ... requested by the login"
- Your IP is not in the firewall rules
- Run the firewall rule creation command from step 2

### Connection timeout
- Verify the server name and database name are correct
- Check that the firewall rule was created successfully
- Ensure you're in the correct Azure subscription

## Important Notes

- Always verify you're targeting the correct subscription/database before running destructive queries
- Use SELECT queries first to verify what will be affected before UPDATE/DELETE
- Clean up firewall rules after completing your work
- The AD admin setting persists - you don't need to set it each time unless it's removed
