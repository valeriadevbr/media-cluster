# Media Cluster

Uma stack completa de servidor de mídia baseada em Kubernetes rodando no Kind (Kubernetes in Docker). Este projeto automatiza o deploy de uma suíte de mídia completa incluindo Plex, Emby, a stack *Arr (Sonarr, Radarr, Lidarr, etc.) e ferramentas de download.

## 📁 Estrutura do Projeto

- **`setup/`**: Scripts de inicialização e manifestos Kubernetes.
  - `k8s/bootstrap/`: Scripts para criar o cluster Kind e instalar dependências.
  - `k8s/`: Manifestos Kubernetes para infraestrutura core e aplicações.
  - `includes/`: Scripts utilitários compartilhados.
- **`scripts/`**: Scripts de automação para gerenciamento de mídia (pós-processamento, transcode, etc.).
- **`configs/`**: Arquivos de configuração persistentes para aplicações.
- **`ssl/`**: Certificados SSL.

## 🚀 Começando

### Pré-requisitos

- Docker
- macOS ou Linux
- `git`
- `curl`

Os scripts de bootstrap tentarão instalar outras dependências como `kind`, `helm`, `kubectl` e `yq`.

### 1. Configuração

Copie o template para um arquivo `.env` e personalize-o:

```bash
cp setup/.env.template setup/.env
nano setup/.env
```

**Variáveis Importantes:**
- `MEDIA_SERVERS_IN_CLUSTER`: Defina como `"true"` para rodar Plex/Emby como pods dentro do cluster. Defina como `"false"` (padrão) para rotear o tráfego para instâncias externas (ex: Docker nativo).
- `MEDIA_PATH`: Caminho para sua biblioteca de mídia no host.
- `DOWNLOADS_PATH`: Caminho para sua pasta de downloads no host.

### 2. Bootstrap do Cluster

Execute o script de criação do cluster. Isso verificará as ferramentas, criará o cluster Kind e configurará a rede (incluindo mapeamento de portas para os servidores de mídia configurados).

```bash
./setup/k8s/bootstrap/01-cluster.sh
```

**Nota:** Se você alterar `MEDIA_SERVERS_IN_CLUSTER` depois, você deve recriar o cluster (`kind delete cluster --name media-cluster` e rodar o script novamente).

### 3. Deploy das Aplicações

Faça o deploy da infraestrutura (Traefik, DNS, Storage) e Aplicações (*Arrs, Plex, Emby):

```bash
./setup/k8s/apply-all.sh
```

Este script detecta automaticamente sua configuração de `MEDIA_SERVERS_IN_CLUSTER` e aplica os manifestos apropriados.

## 🛠️ Gerenciamento

- **Aplicar arquivo específico**: `./setup/k8s/apply.sh <arquivo.yaml>`
- **Verificar Pods**: `kubectl get pods -n media`
- **Acessar Serviços**:
  - Traefik Dashboard: `traefik.media.lan` (se configurado no hosts)
  - Apps: Expostos via IngressRoutes ou NodePorts definidos no `kind-config.yaml`.

## 🧩 Funcionalidades

- **Deploy Condicional**: Rode servidores de mídia pesados (Plex/Emby) dentro ou fora do cluster de forma transparente.
- **Bootstrap Automatizado**: Dependências e configuração do cluster são gerenciadas principalmente por scripts.
- **Integração Kind**: Otimizado para desenvolvimento local/home lab com montagens HostPath para mídia.
