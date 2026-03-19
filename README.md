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

## Installation | Déploiement

### Salesforce
```bash
sf project deploy start --source-dir . --target-org <your-org>
```

### GitHub
Voir [docs/DEPLOYMENT_GIT.md](docs/DEPLOYMENT_GIT.md) pour les instructions de déploiement vers [EmmanuelMery-code/Smatch](https://github.com/EmmanuelMery-code/Smatch).

## License | Licence

© 2026 Emmanuel (EMM)
