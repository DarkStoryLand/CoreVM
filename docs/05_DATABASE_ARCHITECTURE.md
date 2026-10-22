# 05. Microsoft SQL Server 2019 Database Architecture

## 1. Overview
The database engine is deployed using the official Microsoft container image `mcr.microsoft.com/mssql/server:2019-latest`, pinned to Developer/Production mode with a dedicated 16 GB buffer pool cache (`MSSQL_MEMORY_LIMIT_MB=16384`).

---

## 2. Active Databases & Schema Roles

| Database | Description | Critical Tables |
| :--- | :--- | :--- |
| **`MHCMEMBER`** | User accounts, authentication, security status, and Item Mall cash balance | `chr_log_info`, `TB_OPERATOR`, `LoginTable`, `Chr_Parent_info` |
| **`MHGAME`** | Game state, character records, stats, skills, inventory, items, quests, guilds | `TB_CHARACTER`, `TB_ITEM`, `TB_ShopItem`, `TB_MUGONG`, `TB_GUILD` |
| **`MHLOG`** | Real-time audit logs, item transactions, GM commands, trade history, combat | `tb_LogUser`, `tb_speedhack`, `TB_ShopItemUseInfo` |

---

## 3. High-Concurrency Tuning: RCSI Activation
To eliminate blocking locks between high-frequency in-game queries and web portal transactions, **Read Committed Snapshot Isolation (RCSI)** is enabled on all production databases:

```sql
ALTER DATABASE [MHCMEMBER] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [MHCMEMBER] SET READ_COMMITTED_SNAPSHOT ON;
ALTER DATABASE [MHCMEMBER] SET MULTI_USER;

ALTER DATABASE [MHGAME] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [MHGAME] SET READ_COMMITTED_SNAPSHOT ON;
ALTER DATABASE [MHGAME] SET MULTI_USER;

ALTER DATABASE [MHLOG] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [MHLOG] SET READ_COMMITTED_SNAPSHOT ON;
ALTER DATABASE [MHLOG] SET MULTI_USER;
```

---

## 4. Key Table Schemas

### `MHCMEMBER.dbo.chr_log_info` (Primary Account Table)
- `propid` (int, PK): Unique numeric account ID.
- `id_loginid` (varchar 32, Unique): Login username.
- `id_passwd` (varchar 32): Password hash / plain text (verified by DistributeServer).
- `sta_num` (tinyint): Account status (0: Active, 1: Normal, 2: Banned/Blocked).
- `UserLevel` (tinyint): GM authority level (0: Player, 1: Sub-GM, 2: GOD Administrator).
- `WebGold` (int): Player's Mall Cash balance.

### `MHGAME.dbo.TB_ShopItem` (In-Game Delivery Table)
- `Idx` (int): Player Character Index (`CharNo`).
- `ItemIdx` (int): Item Template ID.
- `ItemNum` (int): Quantity / Count.
- `Param1` (int): Durability / Special option parameter.
- `Param2` (int): Enchant / Upgrade tier.
- `RegDate` (smalldatetime): Timestamp of insertion.
