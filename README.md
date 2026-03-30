# SMATCH Async Framework

![Logo SMATCH](ecusson-brode.png)

---
## English | Anglais

### Description
**SMATCH Async Framework** is a Salesforce-native asynchronous task execution framework. It provides a robust, configurable architecture for running background jobs with smart batching, self-healing capabilities, and full observability.

### Key Features
- **Async Task Queue** : Execute tasks defined in custom object `SF_Async__c`
- **Smart Batching** : Dynamic batch size based on historical CPU usage and learned limits
- **Scheduler + Watchdog** : Self-rescheduling scheduler with watchdog for continuity
- **Platform Events** : `Async_WakeUp__e` for real-time triggers (WAKEUP, ERROR, REDUCE_BATCH_SIZE, PARALLEL_WORKERS)
- **Flow Actions** : Invocable methods for Diagnostic, Stop Schedulers, Delete Pending Control, Force Start

### Components
| Component | Description |
|-----------|-------------|
| AsyncWorkerQueueable | Main worker processing pending tasks |
| AsyncScheduler | Cron-based scheduler |
| AsyncWatchdogQueueable | Monitors and restarts if needed |
| AsyncFramework_ForceStart | Flow action to start worker on demand |
| AsyncFramework_Diagnostic | Flow action for framework state |

### Requirements
- Salesforce org (API 59.0+)
- Custom objects: `SF_Async__c`, `SF_Async_Log__c`, `SF_Async_Performance__c`
- Platform Event: `Async_WakeUp__e`

---
## Français

### Description
**SMATCH Async Framework** est un framework d'exécution asynchrone natif Salesforce. Il offre une architecture robuste et configurable pour l'exécution de travaux en arrière-plan avec batching intelligent, auto-récupération et observabilité.

### Fonctionnalités principales
- **File d'attente de tâches** : Exécution des tâches définies dans l'objet personnalisé `SF_Async__c`
- **Batching intelligent** : Taille de lot dynamique selon l'historique CPU et les limites apprises
- **Scheduler + Watchdog** : Scheduler auto-replanifié avec watchdog pour la continuité
- **Platform Events** : `Async_WakeUp__e` pour les déclencheurs temps réel (WAKEUP, ERROR, REDUCE_BATCH_SIZE, PARALLEL_WORKERS)
- **Actions Flow** : Méthodes invocables pour Diagnostic, Arrêt des Schedulers, Suppression des tâches en attente, Démarrage forcé

### Composants
| Composant | Description |
|-----------|-------------|
| AsyncWorkerQueueable | Worker principal traitant les tâches en attente |
| AsyncScheduler | Scheduler basé sur Cron |
| AsyncWatchdogQueueable | Surveille et redémarre si nécessaire |
| AsyncFramework_ForceStart | Action Flow pour démarrer le worker à la demande |
| AsyncFramework_Diagnostic | Action Flow pour l'état du framework |

### Prérequis
- Organisation Salesforce (API 59.0+)
- Objets personnalisés : `SF_Async__c`, `SF_Async_Log__c`, `SF_Async_Performance__c`
- Platform Event : `Async_WakeUp__e`

---
# English Version

## How to Assign a Permission Set to the Automated Process User

In Salesforce, the **Automated Process** user is a system user that does not appear in the standard User list in Setup. To assign it a Permission Set (for example, to grant access to a Named Credential), you must use Anonymous Apex.

### 1. Create your Permission Set
Create your Permission Set normally via the Setup interface and note its API Name (e.g., `My_Permission_Set_API_Name`). Add the required permissions (like Named Credential Access) to it.

### 2. Execute Anonymous Apex
Open the **Developer Console**, navigate to **Debug > Open Execute Anonymous Window**, and run the following code:

```apex
// 1. Find the Automated Process system user
User autoProcUser = [SELECT Id FROM User WHERE Alias = 'autoproc' LIMIT 1];

// 2. Find your Permission Set by its API Name
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'My_Permission_Set_API_Name' LIMIT 1];

// 3. Create the assignment record
PermissionSetAssignment psa = new PermissionSetAssignment(
    AssigneeId = autoProcUser.Id,
    PermissionSetId = ps.Id
);

// 4. Insert the assignment
insert psa;
```
# French Version

## Comment assigner une Permission set à l'utiliateur Automated Process 

Dans Salesforce, l'utilisateur **Automated Process** est un utilisateur système qui n'apparaît pas dans la liste standard des utilisateurs dans la Configuration. Pour lui attribuer un ensemble d'autorisations (par exemple, pour autoriser l'accès à un Named Credential), vous devez utiliser du code Apex anonyme.

### 1. Create your Permission Set
Créez votre Permission Set normalement via l'interface et notez son nom d'API (par exemple : `My_Permission_Set_API_Name`). Ajoutez-y les autorisations requises (comme l'accès aux identifiants nommés).


### 2. Execute Anonymous Apex

Ouvrez la **Developer Console**, allez dans Debug > Open Execute Anonymous Window, et exécutez le code suivant :

```apex
// 1. Trouver l'utilisateur système "Automated Process"
User autoProcUser = [SELECT Id FROM User WHERE Alias = 'autoproc' LIMIT 1];

// 2. Trouver votre Permission Set par son nom d'API
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'My_Permission_Set_API_Name' LIMIT 1];

// 3. Créer le lien d'attribution
PermissionSetAssignment psa = new PermissionSetAssignment(
    AssigneeId = autoProcUser.Id,
    PermissionSetId = ps.Id
);

// 4. Insérer l'enregistrement
insert psa;
```


## Installation | Déploiement

### Salesforce
```bash
sf project deploy start --source-dir . --target-org <your-org>
```
