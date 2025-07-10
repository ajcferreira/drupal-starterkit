
# Générer un rapport complet
generate_full_report() {
    local path=${1:-$CUSTOM_MODULES_PATH}
    
    echo -e "${BLUE}Génération d'un rapport complet...${NC}"
    create_reports_dir
    
    local report_file="$REPORTS_DIR/quality-report-$(date +%Y%m%d_%H%M%S).html"
    
    # Créer le rapport HTML
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Rapport de Qualité de Code - $(date)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007cba; }
        .success { border-left-color: #28a745; }
        .warning { border-left-color: #ffc107; }
        .error { border-left-color: #dc3545; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        .summary { background: #e9ecef; padding: 15px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Rapport de Qualité de Code</h1>
        <p><strong>Date:</strong> $(date)</p>
        <p><strong>Chemin analysé:</strong> $path</p>
    </div>
EOF
    
    # Exécuter les analyses et ajouter au rapport
    run_all "$path"
    local exit_code=$?
    
    # Ajouter les résultats au rapport HTML
    for tool in phpstan phpcs phpmd phpcpd; do
        if [ -f "$REPORTS_DIR/${tool}-report.txt" ]; then
            echo "<div class=\"section\">" >> "$report
            echo "<h2>Rapport $tool</h2>" >> "$report_file"
            echo "<pre>" >> "$report_file"
            cat "$REPORTS_DIR/${tool}-report.txt" >> "$report_file"
            echo "</pre>" >> "$report_file"
            echo "</div>" >> "$report_file"
        fi
    done
    
    # Fermer le HTML
    cat >> "$report_file" << EOF
    <div class="summary">
        <h2>Résumé</h2>
        <p>Analyse terminée le $(date)</p>
        <p>Rapports individuels disponibles dans le dossier: $REPORTS_DIR</p>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}Rapport HTML généré: $report_file${NC}"
    
    # Générer aussi un rapport texte
    local text_report="$REPORTS_DIR/quality-summary-$(date +%Y%m%d_%H%M%S).txt"
    cat > "$text_report" << EOF
=== RAPPORT DE QUALITÉ DE CODE ===
Date: $(date)
Chemin: $path

EOF
    
    for tool in phpstan phpcs phpmd phpcpd; do
        if [ -f "$REPORTS_DIR/${tool}-report.txt" ]; then
            echo "=== $tool ===" >> "$text_report"
            cat "$REPORTS_DIR/${tool}-report.txt" >> "$text_report"
            echo "" >> "$text_report"
        fi
    done
    
    echo -e "${GREEN}Rapport texte généré: $text_report${NC}"
    
    return $exit_code
}

# Fonction pour afficher les statistiques
show_stats() {
    local path=${1:-$CUSTOM_MODULES_PATH}
    
    check_path "$path"
    
    echo -e "${BLUE}=== Statistiques du code ===${NC}"
    
    # Compter les fichiers
    local php_files=$(find "$path" -name "*.php" -type f | wc -l)
    local module_files=$(find "$path" -name "*.module" -type f | wc -l)
    local total_files=$((php_files + module_files))
    
    echo -e "${YELLOW}Fichiers:${NC}"
    echo "  - Fichiers PHP: $php_files"
    echo "  - Fichiers .module: $module_files"
    echo "  - Total: $total_files"
    
    # Compter les lignes de code
    if command -v cloc &> /dev/null; then
        echo -e "\n${YELLOW}Lignes de code:${NC}"
        cloc "$path" --quiet
    else
        local total_lines=$(find "$path" -name "*.php" -o -name "*.module" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
        echo "  - Total lignes: $total_lines"
    fi
    
    # Taille des fichiers
    local total_size=$(du -sh "$path" 2>/dev/null | cut -f1)
    echo -e "\n${YELLOW}Taille totale:${NC} $total_size"
}


# Créer la configuration PHPStan
create_phpstan_config() {
    if [ -f "phpstan.neon" ]; then
        return
    fi
    
    echo -e "${YELLOW}Création de phpstan.neon...${NC}"
    cat > phpstan.neon << 'EOF'
parameters:
  level: 1
  paths:
    - web/modules/custom
    - web/themes/custom
  excludePaths:
    - */node_modules/*
    - */vendor/*
    - */tests/*
  extensions:
    - mglaman\PHPStanDrupal\Extension
  ignoreErrors:
    - '#\Drupal calls should be avoided in classes, use dependency injection instead#'
    - '#Plugin definitions cannot be altered#'
  drupal:
    drupal_root: web
EOF
}


# Génération de rapports
generate_reports() {
    local report_dir="reports"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    log_info "Génération des rapports..."
    mkdir -p "$report_dir"
    
    # Rapport de statut système
    {
        echo "=== RAPPORT SYSTÈME - $timestamp ==="
        echo ""
        echo "=== Services Docker ==="
        docker-compose ps
        echo ""
        echo "=== Statut Drupal ==="
        docker-compose exec php vendor/bin/drush status
        echo ""
        echo "=== Modules activés ==="
        docker-compose exec php vendor/bin/drush pml --status=enabled
        echo ""
        echo "=== Espace disque ==="
        df -h
        echo ""
        echo "=== Utilisation mémoire ==="
        free -h
    } > "$report_dir/system_report_$timestamp.txt"
    
    # Rapport de sécurité
    {
        echo "=== RAPPORT SÉCURITÉ - $timestamp ==="
        echo ""
        echo "=== Mises à jour disponibles ==="
        docker-compose exec php vendor/bin/drush ups
        echo ""
        echo "=== Audit Composer ==="
        docker-compose exec composer composer audit 2>/dev/null || echo "Audit non disponible"
    } > "$report_dir/security_report_$timestamp.txt"
    
    log_success "Rapports générés dans le dossier $report_dir"
}




# Monitoring et santé du système
health_check() {
    log_info "Vérification de la santé du système..."
    
    # Vérification des services Docker
    log_info "État des services Docker:"
    docker-compose ps
    
    # Vérification de l'espace disque
    log_info "Espace disque disponible:"
    df -h
    
    # Vérification de la mémoire
    log_info "Utilisation mémoire:"
    free -h
    
    # Vérification de Drupal
    if docker-compose exec php vendor/bin/drush status &> /dev/null; then
        log_info "Statut Drupal:"
        docker-compose exec php vendor/bin/drush status
    fi
    
    # Vérification de la base de données
    if docker-compose exec mariadb mysql -u root -p${DB_ROOT_PASSWORD} -e "SELECT 1;" &> /dev/null; then
        log_success "Base de données accessible"
    else
        log_error "Problème de connexion à la base de données"
    fi
    
    # Vérification des logs d'erreur
    log_info "Dernières erreurs Drupal:"
    docker-compose exec php vendor/bin/drush watchdog:show --severity=Error --count=5
}

# Optimisation des performances
optimize_performance() {
    log_info "Optimisation des performances..."
    
    # Optimisation Composer
    docker-compose exec composer composer dump-autoload --optimize --classmap-authoritative
    
    # Optimisation Drupal
    docker-compose exec php vendor/bin/drush config:set system.performance css.preprocess 1 -y
    docker-compose exec php vendor/bin/drush config:set system.performance js.preprocess 1 -y
    docker-compose exec php vendor/bin/drush cache:rebuild
    
    # Optimisation de la base de données
    docker-compose exec mariadb mysql -u root -p${DB_ROOT_PASSWORD} -e "OPTIMIZE TABLE ${DB_NAME}.*;"
    
    log_success "Optimisation terminée"
}

# Sécurité et mise à jour
security_updates() {
    log_info "Vérification des mises à jour de sécurité..."
    
    # Mise à jour des dépendances Composer
    docker-compose exec composer composer update --with-dependencies
    
    # Vérification des vulnérabilités
    if docker-compose exec composer composer audit &> /dev/null; then
        docker-compose exec composer composer audit
    fi
    
    # Mise à jour Drupal core et modules
    docker-compose exec php vendor/bin/drush pm:security-php
    docker-compose exec php vendor/bin/drush ups --security-only
    
    log_success "Vérification de sécurité terminée"
}


# Mise à jour de la base de données
update_database() {
    log_info "Mise à jour de la base de données..."
    
    # Sauvegarde de la base de données
    backup_database
    
    # Mise à jour de la base de données
    docker-compose exec php vendor/bin/drush updatedb --yes
    docker-compose exec php vendor/bin/drush config:import --yes
    docker-compose exec php vendor/bin/drush cache:rebuild
    
    log_success "Base de données mise à jour"
}

# Sauvegarde de la base de données
backup_database() {
    local backup_dir="backups"
    local backup_file="$backup_dir/backup_$(date +%Y%m%d_%H%M%S).sql"
    
    log_info "Sauvegarde de la base de données..."
    mkdir -p "$backup_dir"
    
    docker-compose exec mariadb mysqldump -u root -p${DB_ROOT_PASSWORD} ${DB_NAME} > "$backup_file"
    
    # Garder seulement les 10 dernières sauvegardes
    ls -t "$backup_dir"/backup_*.sql | tail -n +11 | xargs -r rm
    
    log_success "Base de données sauvegardée: $backup_file"
}

# Restauration de la base de données
restore_database() {
    local backup_file=$1
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        log_error "Fichier de sauvegarde non trouvé: $backup_file"
        return 1
    fi
    
    log_info "Restauration de la base de données depuis: $backup_file"
    docker-compose exec -T mariadb mysql -u root -p${DB_ROOT_PASSWORD} ${DB_NAME} < "$backup_file"
    docker-compose exec php vendor/bin/drush cache:rebuild
    log_success "Base de données restaurée"
}

# Tests de qualité du code
run_quality_tests() {
    log_info "Exécution des tests de qualité..."
    
    # PHPStan
    if docker-compose exec composer composer show phpstan/phpstan &> /dev/null; then
        log_info "Analyse PHPStan..."
        docker-compose exec php vendor/bin/phpstan analyse web/modules/custom web/themes/custom
    fi
    
    # PHP_CodeSniffer
    if docker-compose exec composer composer show squizlabs/php_codesniffer &> /dev/null; then
        log_info "Vérification du style de code..."
        docker-compose exec php vendor/bin/phpcs --standard=Drupal,DrupalPractice web/modules/custom web/themes/custom
    fi
    
    # PHPUnit
    log_info "Exécution des tests PHPUnit..."
    docker-compose exec php vendor/bin/phpunit --configuration web/core/phpunit.xml.dist web/modules/custom
    
    log_success "Tests de qualité terminés"
}

# Correction du style de code
fix_code_style() {
    log_info "Correction automatique du style de code..."
    
    # PHP Code Beautifier and Fixer
    if docker-compose exec composer composer show squizlabs/php_codesniffer &> /dev/null; then
        docker-compose exec php vendor/bin/phpcbf --standard=Drupal web/modules/custom web/themes/custom
        log_success "Style de code corrigé"
    else
        log_warning "PHP_CodeSniffer n'est pas installé"
    fi
}

# Installation des outils de qualitéce
install_quality_tools() {
    log_info "Installation des outils de qualité..."
    
    docker-compose exec composer composer require --dev \
        phpstan/phpstan \
        phpstan/phpstan-drupal \
        mglaman/phpstan-drupal \
        squizlabs/php_codesniffer \
        drupal/coder
    
    # Configuration de PHP_CodeSniffer
    docker-compose exec php vendor/bin/phpcs --config-set installed_paths vendor/drupal/coder/coder_sniffer
    
    log_success "Outils de qualité installés"
}

# Nettoyage
cleanup() {
    log_info "Nettoyage..."
    docker-compose exec php vendor/bin/drush cache:rebuild
    docker-compose exec php vendor/bin/drush cr
    docker system prune -f
    log_success "Nettoyage terminé"
}

# Mise à jour de la base de données
update_database() {
    log_info "Mise à jour de la base de données..."
    
    # Sauvegarde de la base de données
    backup_database
    
    # Mise à jour de la base de données
    docker-compose exec php vendor/bin/drush updatedb --yes
    docker-compose exec php vendor/bin/drush config:import --yes
    docker-compose exec php vendor/bin/drush cache:rebuild
    
    log_success "Base de données mise à jour"
}

# Sauvegarde de la base de données
backup_database() {
    local backup_dir="backups"
    local backup_file="$backup_dir/backup_$(date +%Y%m%d_%H%M%S).sql"
    
    log_info "Sauvegarde de la base de données..."
    mkdir -p "$backup_dir"
    
    docker-compose exec mariadb mysqldump -u root -p${DB_ROOT_PASSWORD} ${DB_NAME} > "$backup_file"
    
    # Garder seulement les 10 dernières sauvegardes
    ls -t "$backup_dir"/backup_*.sql | tail -n +11 | xargs -r rm
    
    log_success "Base de données sauvegardée: $backup_file"
}

# Restauration de la base de données
restore_database() {
    local backup_file=$1
    
    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        log_error "Fichier de sauvegarde non trouvé: $backup_file"
        return 1
    fi
    
    log_info "Restauration de la base de données depuis: $backup_file"
    docker-compose exec -T mariadb mysql -u root -p${DB_ROOT_PASSWORD} ${DB_NAME} < "$backup_file"
    docker-compose exec php vendor/bin/drush cache:rebuild
    log_success "Base de données restaurée"
}
