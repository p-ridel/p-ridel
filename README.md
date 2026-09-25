# 🚀 Plataforma Ridel — Runtime do Desenvolvedor

Bem-vindo à **Plataforma Ridel**, uma infraestrutura corporativa declarativa de alta performance que fornece uma engine de dados reativa e o **Universal Player** integrado para execução imediata de sistemas empresariais.

---

## 🏛️ Filosofia: Desenvolvimento 100% Declarativo

Na Plataforma Ridel, você **não precisa programar telas em Flutter, nem construir APIs CRUD repetitivas, nem gerenciar migrações de SQL complexas**.

Todo o seu sistema é construído declarando entidades, regras e telas em Python dentro do diretório persistente de tenants (`/data/tenants/`):

* **`tables.py`**: Modelagem de dados declarativa, campos tipados, validações, constraints e relacionamentos de chave estrangeira.
* **`views.py`**: Definição das interfaces do usuário (listagens em grid, formulários de edição, telas de detalhes e kanbans).
* **`roles.py`**: Perfis de acesso e controle de permissões granulares por tabela (RBAC).
* **`actions.py`**: Regras de negócio, mutações e rotinas automatizadas no servidor com o decorador `@action`.
* **`app.py`**: Metadados do aplicativo (título, ícone canônico, cor tema e versão).
* **`user.py`**: Instanciação declarativa de usuários locais e associação aos seus papéis.

---

## ⚡ Instalação Rápida

### 1. Ativar a CLI Ridel no seu Terminal (Host)
Instale a CLI oficial da Plataforma Ridel no seu computador com um único comando:

```bash
curl -fsSL https://raw.githubusercontent.com/p-ridel/p-ridel/main/install.sh | bash
```

> 💡 **Alternativa Zero-Download:** Se você já estiver com o contêiner Docker em execução, pode extrair a CLI diretamente com:
> ```bash
> docker cp ridel:/usr/local/bin/ridel ~/.local/bin/ridel
> ```

### 2. Iniciar a Plataforma via Docker
Execute a plataforma completa com persistência unificada através do comando:

```bash
# 1. Cria um diretório no host para persistir o cluster de banco, tenants e arquivos:
mkdir -p ~/ridel-data

# 2. Inicia o contêiner oficial com volume persistente montado em /data:
docker run -d \
  --name ridel \
  --restart unless-stopped \
  -p 8000:8000 \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD="sua_senha_segura_de_banco" \
  -v ~/ridel-data:/data \
  ghcr.io/p-ridel/p-ridel:latest
```

> 💡 **Parâmetros Opcionais:**
> * `-e POSTGRES_USER="ridel"`: Define o usuário do PostgreSQL (padrão: `ridel`).
> * `-e POSTGRES_DB="ridel"`: Define o nome do banco de dados principal (padrão: `ridel`).
> * `-e SECRET_KEY="sua_chave"`: Define uma chave criptográfica customizada (se omitida, uma chave persistente é gerada automaticamente em `/data/.secret_key`).

---

## 🌐 Acesso à Plataforma

Após iniciar o contêiner:
* **Aplicação Web (Universal Player):** [`http://localhost:8000/`](http://localhost:8000/)
* **Documentação Interativa da API (Swagger):** [`http://localhost:8000/docs`](http://localhost:8000/docs)
* **Credenciais de Primeiro Boot (Tenant Demo):**
  * **E-mail:** `admin@demo.com`
  * **Senha:** `admin123`

---

## 🛠️ Comandos da CLI Ridel

Com a CLI instalada no seu host, você executa todos os comandos diretamente no seu terminal, sem necessidade de sintaxes longas com `docker exec`:

### Gestão do Ciclo de Vida da Plataforma
```bash
# Verificar status do contêiner e saúde da engine
ridel status

# Iniciar ou parar a plataforma
ridel start
ridel stop
ridel restart

# Acompanhar logs em tempo real
ridel logs
```

### Criar um novo Tenant estruturado
```bash
ridel tenant create meu_sistema --title "Meu Sistema"
```
Este comando cria a estrutura completa de arquivos declarativos em `/data/tenants/meu_sistema/` (refletida instantaneamente na sua pasta local `~/ridel-data/tenants/meu_sistema/`).

### Validar a integridade declarativa do Tenant
```bash
ridel check meu_sistema
```
O checker estático valida tipagens, chaves primárias, relacionamentos FK, referências em views e consistência das permissões RBAC.

### Atualizar a Plataforma para a Última Versão Oficial
```bash
ridel update [versao]   # ou use o alias: ridel att
```
Atualiza o contêiner para a versão mais recente (ou versão específica) do GitHub Container Registry (`ghcr.io/p-ridel/p-ridel`) e sincroniza a CLI do host. Preserva **100% dos volumes montados (`~/ridel-data`), dados do banco e portas**, cria um snapshot local da versão anterior para rollback e executa verificação de saúde (`/health`).

### Reverter para a Versão Anterior (Rollback)
```bash
ridel rollback
```
Reverte instantaneamente para o snapshot local da versão anterior em caso de qualquer falha ou incompatibilidade, sem necessidade de internet ou novo download (< 3 segundos).

### Atualizar a CLI Ridel no Host
```bash
ridel cli update
```
Baixa e atualiza o próprio script executável `ridel` diretamente do repositório oficial no GitHub.

---

## 🔄 Fluxo de Desenvolvimento no Dia a Dia

A Plataforma Ridel utiliza **Server-Driven UI (SDUI)** e **Auto-Reconciliação Contínua de Schema (DDL)**. Durante o desenvolvimento do tenant, **quase nunca é necessário reiniciar o backend ou o frontend**.

### Como proceder para cada alteração:

| O que você alterou | Arquivo | Backend | Frontend | Banco de Dados |
| :--- | :--- | :--- | :--- | :--- |
| **Criar novo campo** | `tables.py` | Nada (Auto-reload) | Clicar **"Atualizar Dados"** | Auto-reconciliação DDL |
| **Criar nova tabela** | `tables.py` | Nada (Auto-reload) | Clicar **"Atualizar Dados"** | Auto-reconciliação DDL |
| **Alterar rótulo/ordem em tela** | `views.py` | Nada (Auto-reload) | Clicar **"Atualizar Dados"** | Nenhuma ação |
| **Adicionar opção a Enum** | `tables.py` | Nada (Auto-reload) | Clicar **"Atualizar Dados"** | Nenhuma ação |
| **Alterar regras de `@action`** | `actions.py` | Nada (Auto-reload) | Clicar **"Atualizar Dados"** | Nenhuma ação |
| **Alterar fórmulas (`@formula`)** | `tables.py` | Nada (Auto-reload) | Clicar **"Atualizar Dados"** | Nenhuma ação |
| **Adicionar dados de teste** | `seed.py` | Nada | Clicar **"Atualizar Dados"** | Executar `make seed` |
| **Alterar perfis ou acessos** | `roles.py` | Nada (Auto-reload) | Fazer **Logout e Login** | Nenhuma ação |
| **Instalar pacote Python** | `pyproject.toml` | Reiniciar (`make backend`) | Nenhuma ação | Nenhuma ação |
| **Alterar código Flutter** | `frontend/**/*.dart`| Nenhuma ação | Hot Reload (`r`) ou F5 | Nenhuma ação |

> 📖 **Especificação Completa:** Para detalhes arquiteturais profundos, garantias de reatividade e funcionamento interno das 4 camadas, consulte o documento canônico **[Metodologia e Fluxo de Desenvolvimento](docs/METODOLOGIA_DESENVOLVIMENTO_RIDEL.md)**.
>
> 💡 **Atenção às Portas no Desenvolvimento Local:** Em desenvolvimento na máquina local, acesse o frontend na porta **`3000`** (`http://localhost:3000`) para usufruir do Hot Reload instantâneo. A porta **`8000`** é estritamente a API FastAPI (acessar a raiz redireciona para `/docs`). A unificação de frontend compilado e backend na porta 8000 ocorre exclusivamente dentro do contêiner Docker All-in-One de produção.

---

## 📚 Documentação Adicional

Para aprofundar-se em todos os tipos de campos, decoradores de ação e convenções declarativas:
* Consulte o **[Manual Oficial do Desenvolvedor de Tenants](docs/MANUAL_DO_DESENVOLVEDOR_TENANTS.md)**.
* Consulte a especificação de **[Metodologia e Fluxo de Desenvolvimento](docs/METODOLOGIA_DESENVOLVIMENTO_RIDEL.md)**.

