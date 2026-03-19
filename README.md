# Media Cluster

Uma stack completa de servidor de mídia baseada em Kubernetes, rodando em um único cluster **Kind** (Kubernetes in Docker) no macOS. O projeto automatiza o deploy de toda a suíte de mídia, separando responsabilidades por **namespaces** (`infra` e `media`) dentro de um único cluster chamado `homelab-cluster`.

---

## 🏗 Arquitetura

O cluster utiliza dois namespaces para isolar responsabilidades:

### Namespace `infra`
Serviços essenciais e de infraestrutura de rede:

| Serviço | Função |
| :--- | :--- |
| **BIND9** | DNS local com Split-Horizon para domínios `.media.lan` |
| **AdGuard Home** | Bloqueio de anúncios e DNS secundário |
| **Traefik** | Ingress controller (roteamento e TLS via Cert-Manager) |
| **Cert-Manager** | Gestão de certificados TLS (ACME / Dynu) |
| **External-DNS** | Sincronização de registros DNS com o BIND9 |
| **Dashboard** | Kubernetes Dashboard |
| **Speedtest** | Teste de velocidade de internet |

### Namespace `media`
Aplicações de mídia e automação:

| Serviço | Função |
| :--- | :--- |
| **Plex** | Servidor de mídia principal |
| **Emby** | Servidor de mídia alternativo |
| **Navidrome** | Streaming de música (estilo Subsonic) |
| **Feishin** | Cliente web para Navidrome |
| **qBittorrent** | Download via torrent |
| **Slskd** | Cliente Soulseek (música) |
| **Sonarr** | Gestão automática de séries |
| **Radarr** | Gestão automática de filmes |
| **Lidarr** | Gestão automática de músicas |
| **Bazarr** | Download automático de legendas |
| **Lingarr** | Tradução de legendas com IA |
| **Prowlarr** | Indexador central (Arrs) |
| **Jackett** | Indexador adicional |
| **FlareSolverr** | Bypass de Cloudflare para indexadores |
| **Profilarr** | Gestão de perfis de qualidade nos Arrs |
| **Postgres** | Banco de dados relacional compartilhado |
| **Webshare** | Compartilhamento de arquivos via web |

---

## 🚀 Instalação e Setup

### 1. Pré-requisitos

- **Docker** ou **OrbStack**
- **Kind** (`brew install kind`)
- **Kubectl** (`brew install kubectl`)
- **Helm** (`brew install helm`)

### 2. Configuração

Copie o template de variáveis de ambiente e preencha com os seus valores:

```bash
cp setup/.env.template setup/.env
```

Principais variáveis a configurar:

| Variável | Descrição |
| :--- | :--- |
| `CLUSTER_NAME` | Nome do cluster Kind (padrão: `homelab-cluster`) |
| `DOCKER_HOST_IP` | IP do host Docker na rede interna |
| `MEDIA_PATH` | Caminho para a biblioteca de mídia |
| `PLEX_AUTH_TOKEN` / `PLEX_CLAIM` | Credenciais do Plex |
| `ACME_EMAIL` / `DYNU_API_KEY` | Configuração de TLS via ACME |
| `POSTGRES_*` / `*_DB_PASSWORD` | Credenciais do banco de dados |
| `WG_*` | Configurações do WireGuard |
| `MEDIA_SERVERS_IN_CLUSTER` | `true` para expor Plex/Emby via HostPort |

### 3. Bootstrap

O script principal orquestra a criação do cluster e o deploy de todos os recursos:

```bash
./setup/init.sh
```

*Para rodar apenas as etapas de Kubernetes (sem tools do host):*
```bash
./setup/k8s/setup.sh
```

O bootstrap executa sequencialmente os scripts em `setup/k8s/bootstrap/`:

| Script | O que faz |
| :--- | :--- |
| `00-tools.sh` | Valida ferramentas necessárias (kind, kubectl, helm…) |
| `01-cluster.sh` | Cria o cluster Kind e aplica tunning de rede (sysctl, MTU, offloading) |
| `02-namespaces.sh` | Cria os namespaces `infra` e `media` |
| `03-global.sh` | Aplica recursos globais (CoreDNS patch, External-DNS) |
| `04-bind-keys.sh` | Gera chaves TSIG para o BIND9 |
| `05-secrets.sh` | Cria Secrets (TLS, API keys, credenciais) |
| `06-cert-manager.sh` | Instala o Cert-Manager via Helm |
| `07-traefik-infra.sh` | Instala o Traefik do namespace `infra` |
| `08-traefik-media.sh` | Instala o Traefik do namespace `media` |
| `09-metrics-server.sh` | Instala o Metrics Server |
| `10-reflector.sh` | Instala o Reflector (replicação de Secrets entre namespaces) |
| `11-resources-infra.sh` | Aplica todos os manifests do namespace `infra` |
| `11-resources-media.sh` | Aplica todos os manifests do namespace `media` |

---

## ⚙️ Configurações Avançadas

### Tunning de Rede

Durante a criação do cluster, os seguintes ajustes são aplicados ao nó via `sysctl` e `ethtool`:

- **MTU**: Ajustado para compatibilidade com a rede Docker.
- **Offloading**: TSO, GSO e GRO são desativados para melhor compatibilidade com drivers de rede virtualizados.
- **TCP Buffers**: `rmem` e `wmem` ampliados para suportar janelas TCP maiores em streaming e transferências SMB/NFS.

### Mapeamento de Portas (HostPorts)

A variável `MEDIA_SERVERS_IN_CLUSTER` no `.env` controla como Plex e Emby são expostos:

- **`true`**: As portas (ex: 32400, 8920) são mapeadas diretamente no host via `hostPort` e `extraPortMappings` do Kind, permitindo descoberta DLNA/L2.
- **`false`**: As aplicações são acessadas exclusivamente via Ingress (Traefik).

### WireGuard

O projeto inclui suporte a WireGuard para acesso remoto seguro. As configurações de peers são feitas no `.env` e os arquivos de configuração são gerados em `setup/wireguard-macos/`.

---

## 📁 Estrutura de Pastas

```
media-cluster/
├── configs/                        # Configurações de apps (AdGuard, Plex, etc.)
├── scripts/
│   ├── host/                       # Scripts de manutenção do host macOS
│   ├── arr/                        # Scripts utilitários para os Arrs
│   └── k8s/                        # Scripts utilitários para o cluster
├── ssl/                            # Certificados TLS locais
└── setup/
    ├── .env.template               # Template de variáveis de ambiente
    ├── init.sh                     # Ponto de entrada principal
    ├── includes/                   # Bibliotecas Shell compartilhadas
    │   ├── load-env.sh
    │   ├── k8s-utils.sh
    │   └── pkg-utils.sh
    └── k8s/
        ├── setup.sh                # Orquestrador do bootstrap K8s
        ├── unload.sh               # Remove o cluster
        ├── bootstrap/              # Scripts de criação e configuração do cluster
        ├── global/                 # Recursos aplicados globalmente (CoreDNS, External-DNS)
        ├── infra/                  # Manifests do namespace infra
        │   ├── 00-core/            # PriorityClass
        │   ├── 01-storage/         # PersistentVolumes e PVCs
        │   ├── 02-ingress/         # IngressRoutes (Traefik)
        │   ├── 03-apps/            # Deployments (BIND9, AdGuard, Dashboard…)
        │   └── 04-maintenance/     # CronJobs e RBAC de manutenção
        └── media/                  # Manifests do namespace media
            ├── 00-core/            # PriorityClass
            ├── 01-storage/         # PersistentVolumes e PVCs
            ├── 02-ingress/         # IngressRoutes (Traefik)
            └── 03-apps/            # Deployments (Plex, Sonarr, Lidarr…)
```

---

## 🧹 Remoção

Para remover o cluster e limpar o ambiente:

```bash
./setup/unload.sh
```

Para remover apenas um dos namespaces de recursos (sem destruir o cluster):

```bash
./setup/k8s/unload-infra.sh
./setup/k8s/unload-media.sh
```
