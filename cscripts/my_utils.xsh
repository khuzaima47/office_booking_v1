#!/usr/bin/xonsh


def grant_full_permissions(dir):
    find @(dir) -type d -exec chmod u=rwx,g=rwx,o=rwx '{}' ';'
    find @(dir) -type f -exec chmod u=rwx,g=rwx,o=rwx '{}' ';'


def ensure_user(user):
    u = $(whoami).strip()
    if u := user:
        print(f'✔️ user is {user}️')
    else:
        raise Exception(f'❌ User must be {user}! Current user is: {u}')


def config_dir(dirname, user, group, chmod):
    mkdir -p @(dirname)
    chown -R @(user):@(group) @(dirname)
    chmod @(chmod) @(dirname)
    print(f'✔️ configured {dirname} with user: {user}, group: {group}, permissions: {chmod}')