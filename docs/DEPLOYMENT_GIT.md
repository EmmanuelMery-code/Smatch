# Déploiement Smatch sur GitHub

Ce guide décrit comment déployer le package Smatch depuis `C:\Users\emery\Desktop\SMATCH\gitPackage` vers le dépôt GitHub [EmmanuelMery-code/Smatch](https://github.com/EmmanuelMery-code/Smatch).

---

## Prérequis

- [Git](https://git-scm.com/downloads) installé
- Compte GitHub avec accès au dépôt
- Authentification GitHub configurée (HTTPS ou SSH)

---

## Méthode 1 : Premier déploiement (nouveau dépôt local)

Si le dossier `gitPackage` n'est **pas encore** un dépôt Git :

### Étape 1 : Se placer dans le dossier gitPackage

```powershell
cd C:\Users\emery\Desktop\SMATCH\gitPackage
```

### Étape 2 : Initialiser le dépôt Git

```powershell
git init
```

### Étape 3 : Ajouter le dépôt distant

```powershell
git remote add origin https://github.com/EmmanuelMery-code/Smatch.git
```

Pour utiliser SSH :
```powershell
git remote add origin git@github.com:EmmanuelMery-code/Smatch.git
```

### Étape 4 : Vérifier les fichiers à inclure

```powershell
git status
```

Les dossiers `.sfdx/`, `coverage/`, `.idea/`, `.vscode/` sont ignorés via `.gitignore`.

### Étape 5 : Ajouter les fichiers et effectuer le premier commit

```powershell
git add .
git commit -m "Initial commit - Smatch Async Framework"
```

### Étape 6 : Renommer la branche en main

```powershell
git branch -M main
```

### Étape 7 : Pousser vers GitHub

Si le dépôt distant contient déjà du contenu (ex. README) :

```powershell
git pull origin main --allow-unrelated-histories
git push -u origin main
```

Si le dépôt est vide :

```powershell
git push -u origin main
```

---

## Méthode 2 : Dépôt Git déjà initialisé

### Vérifier le remote

```powershell
cd C:\Users\emery\Desktop\SMATCH\gitPackage
git remote -v
```

Modifier l'URL si nécessaire :

```powershell
git remote set-url origin https://github.com/EmmanuelMery-code/Smatch.git
```

### Ajouter les modifications et pousser

```powershell
git add .
git status
git commit -m "Message décrivant les changements"
git push origin main
```

---

## Déploiement Salesforce

Pour déployer ce package vers une org Salesforce (depuis le parent `smatch` ou en ajoutant `sfdx-project.json`) :

Depuis le dossier parent smatch :
```powershell
cd C:\Users\emery\Desktop\SMATCH\smatch
sf project deploy start --source-dir ..\gitPackage --target-org smatch
```

Ou depuis gitPackage si `sfdx-project.json` est présent à la racine :
```powershell
cd C:\Users\emery\Desktop\SMATCH\gitPackage
sf project deploy start --source-dir . --target-org smatch
```

---

## Authentification GitHub

### Option A : HTTPS avec Token (recommandé)

1. Créer un [Personal Access Token (PAT)](https://github.com/settings/tokens)
2. Lors du `git push`, utiliser le token comme mot de passe

### Option B : SSH

1. Générer une clé : `ssh-keygen -t ed25519 -C "votre@email.com"`
2. Ajouter la clé à [GitHub SSH keys](https://github.com/settings/keys)
3. Utiliser l'URL SSH : `git@github.com:EmmanuelMery-code/Smatch.git`

---

## Commandes utiles

| Action | Commande |
|--------|----------|
| Voir l'état | `git status` |
| Voir les remotes | `git remote -v` |
| Branche | `git checkout -b feature/nom` |
| Récupérer | `git pull origin main` |
| Annuler un add | `git restore --staged fichier` |

---

## Dépannage

**« failed to push some refs »**
```powershell
git pull origin main --rebase
git push origin main
```

**« remote origin already exists »**
```powershell
git remote remove origin
git remote add origin https://github.com/EmmanuelMery-code/Smatch.git
```
