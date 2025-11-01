import os
import stat


def create_directory_structure():
    """Создает структуру каталогов для Ansible конфигурации виртуальных машин"""

    base_path = "ansible-vm-configuration"

    # Определяем структуру каталогов
    structure = {
        "inventories": {
            "production": {
                "host_vars": {
                    "vm01.example.com.yml": "",
                    "vm02.example.com.yml": ""
                },
                "group_vars": {
                    "all.yml": "",
                    "web-servers.yml": "",
                    "db-servers.yml": ""
                },
                "hosts": ""
            },
            "staging": {
                "hosts": ""
            },
            "development": {
                "hosts": ""
            }
        },
        "playbooks": {
            "change-hostname.yml": "",
            "change-ip-address.yml": "",
            "change-gateway-netmask.yml": "",
            "change-dns-servers.yml": "",
            "comprehensive-network-config.yml": "",
            "rollback-network-changes.yml": ""
        },
        "roles": {
            "hostname": {
                "tasks": {"main.yml": ""},
                "handlers": {"main.yml": ""},
                "templates": {},
                "defaults": {"main.yml": ""}
            },
            "network-ip": {
                "tasks": {"main.yml": ""},
                "handlers": {"main.yml": ""},
                "templates": {},
                "defaults": {"main.yml": ""}
            },
            "network-gateway": {
                "tasks": {"main.yml": ""},
                "handlers": {"main.yml": ""},
                "templates": {},
                "defaults": {"main.yml": ""}
            },
            "network-dns": {
                "tasks": {"main.yml": ""},
                "handlers": {"main.yml": ""},
                "templates": {},
                "defaults": {"main.yml": ""}
            }
        },
        "templates": {
            "netplan-config.j2": "",
            "interfaces-config.j2": "",
            "ifcfg-config.j2": "",
            "systemd-network-config.j2": ""
        },
        "files": {
            "backup-scripts": {},
            "validation-scripts": {}
        },
        "group_vars": {
            "all.yml": "",
            "linux-servers.yml": "",
            "network-devices.yml": ""
        },
        "host_vars": {
            "vm01.example.com.yml": "",
            "vm02.example.com.yml": ""
        },
        "library": {
            "custom_network_utils.py": ""
        },
        "filter_plugins": {
            "network_filters.py": ""
        },
        "scripts": {
            "pre-flight-check.sh": "",
            "post-validation.sh": ""
        },
        "requirements.yml": "",
        "ansible.cfg": "",
        "README.md": ""
    }

    def create_structure(base, structure_dict):
        """Рекурсивно создает структуру каталогов и файлов"""
        for name, content in structure_dict.items():
            path = os.path.join(base, name)

            if isinstance(content, dict):
                # Это каталог
                os.makedirs(path, exist_ok=True)
                print(f"Создан каталог: {path}")
                create_structure(path, content)
            else:
                # Это файл
                with open(path, 'w', encoding='utf-8') as f:
                    # Добавляем базовое содержимое для некоторых файлов
                    if name.endswith('.yml'):
                        f.write("---\n# Конфигурационный файл\n")
                    elif name.endswith('.py'):
                        f.write('"""Модуль для работы с сетью"""\n\n')
                    elif name.endswith('.sh'):
                        f.write("#!/bin/bash\n\n")
                    elif name == 'README.md':
                        f.write("# Ansible VM Configuration\n\n")
                    elif name == 'ansible.cfg':
                        f.write(
                            "[defaults]\ninventory = inventories/\nhost_key_checking = False\n")
                    elif name == 'requirements.yml':
                        f.write(
                            "# Роли из Ansible Galaxy\n- src: username.role_name\n")

                # Делаем скрипты исполняемыми
                if name.endswith('.sh'):
                    st = os.stat(path)
                    os.chmod(path, st.st_mode | stat.S_IEXEC)

                print(f"Создан файл: {path}")

    # Создаем базовый каталог
    os.makedirs(base_path, exist_ok=True)
    print(f"Создан базовый каталог: {base_path}")

    # Создаем структуру
    create_structure(base_path, structure)

    # Создаем дополнительные файлы в подкаталогах
    create_additional_files(base_path)


def create_additional_files(base_path):
    """Создает дополнительные файлы с примерным содержимым"""

    # Пример содержимого для inventory файлов
    inventory_content = {
        "production/hosts": """[web-servers]
vm01.example.com
vm02.example.com

[db-servers]
vm01.example.com

[all:vars]
ansible_ssh_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
""",
        "staging/hosts": """[all]
staging-vm01.example.com

[all:vars]
ansible_ssh_user=ubuntu
""",
        "development/hosts": """[all]
dev-vm01.example.com

[all:vars]
ansible_ssh_user=ubuntu
"""
    }

    # Записываем содержимое inventory файлов
    for rel_path, content in inventory_content.items():
        full_path = os.path.join(base_path, "inventories", rel_path)
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Заполнен файл: {full_path}")

    # Пример playbook для смены hostname
    change_hostname_playbook = """---
- name: Change VM hostname
  hosts: all
  become: yes
  vars:
    new_hostname: "{{ inventory_hostname }}"
  
  tasks:
    - name: Set hostname
      hostname:
        name: "{{ new_hostname }}"
      
    - name: Update /etc/hosts
      lineinfile:
        path: /etc/hosts
        regexp: '^127.0.1.1'
        line: '127.0.1.1 {{ new_hostname }}'
        
    - name: Restart systemd-hostnamed
      systemd:
        name: systemd-hostnamed
        state: restarted
      when: ansible_service_mgr == "systemd"
"""

    with open(os.path.join(base_path, "playbooks", "change-hostname.yml"), 'w', encoding='utf-8') as f:
        f.write(change_hostname_playbook)

    # Пример задачи для роли hostname
    hostname_tasks = """---
- name: Ensure hostname is set
  hostname:
    name: "{{ vm_hostname }}"
  
- name: Update hosts file
  lineinfile:
    path: /etc/hosts
    regexp: '^127.0.1.1'
    line: '127.0.1.1 {{ vm_hostname }}'
    state: present
"""

    with open(os.path.join(base_path, "roles", "hostname", "tasks", "main.yml"), 'w', encoding='utf-8') as f:
        f.write(hostname_tasks)


def main():
    """Основная функция"""
    print("Создание структуры Ansible проекта...")
    try:
        create_directory_structure()
        print("\nСтруктура проекта:")
        print_tree("ansible-vm-configuration")
    except Exception as e:
        print(f"Ошибка при создании структуры: {e}")


def print_tree(start_path, prefix="", is_last=True):
    """Выводит дерево каталогов в консоль"""
    if os.path.isfile(start_path):
        return

    items = sorted(os.listdir(start_path))
    for i, item in enumerate(items):
        path = os.path.join(start_path, item)
        is_last_item = (i == len(items) - 1)

        if os.path.isfile(path):
            connector = "└── " if is_last_item else "├── "
            print(f"{prefix}{connector}{item}")
        else:
            connector = "└── " if is_last_item else "├── "
            print(f"{prefix}{connector}{item}/")
            new_prefix = prefix + ("    " if is_last_item else "│   ")
            print_tree(path, new_prefix, is_last_item)


if __name__ == "__main__":
    main()
