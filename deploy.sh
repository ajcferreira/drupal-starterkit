
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
