# Media Cluster

Uma stack completa de servidor de mídia baseada em Kubernetes rodando em **Dual Cluster** no Kind (Kubernetes in Docker). Este projeto automatiza o deploy de uma suíte de mídia completa, separando serviços de infraestrutura crítica (DNS) das aplicações de média.

## 🏗 Arquitetura

O ambiente é dividido em dois clusters Kind para garantir resiliência do DNS local:
1.  **`infra-cluster`**: Roda serviços essenciais de rede e DNS (BIND). Garante que a resolução de nomes `.media.lan` continue funcionando mesmo que o cluster de mídia seja reiniciado.
2.  **`media-cluster`**: Roda as aplicações (Plex, Emby, *Arrs, Traefik).

## 📁 Estrutura do Projeto

- **`setup/`**: Scripts de inicialização e manifestos Kubernetes.
  - `k8s/`
    - `bootstrap/`: Scripts para criar os clusters (`01-cluster-infra.sh`, `02-cluster-media.sh`).
    - `infra/`: Manifestos do cluster Infra (Core, Storage, DNS).
    - `media/`: Manifestos do cluster Media (Core, Ingress, Apps).
    - `apply-*.sh`: Scripts para aplicar resources em cada cluster.
    - `unload-*.sh`: Scripts para destruição graciosa.
  - `includes/`: Scripts utilitários compartilhados.
- **`scripts/`**: Scripts de automação para gerenciamento de mídia.
- **`configs/`**: Arquivos de configuração persistentes.
- **`ssl/`**: Certificados SSL.

## 🔒 Segurança & Certificados

O projeto utiliza uma estratégia híbrida de certificados para garantir segurança e confiança tanto em redes internas quanto externas:

1.  **LAN (Interno)**:
    - Utiliza uma **CA (Certificado de Autoridade) Local**.
    - Os certificados para `*.media.lan` são gerados e assinados por essa CA.
    - *Script*: `setup/utils/gen-lan-ssl-cert.sh`

2.  **WAN (Externo)**:
    - Utiliza certificados reais (geralmente Let's Encrypt / Certbot) gerados manualmente via script.
    - O certificado inclui todos os subdomínios necessários (`plex`, `emby`, `dashboard`, etc.) como SANs (Subject Alternative Names).
    - *Script*: `setup/utils/gen-wan-ssl-cert.sh` - Gera o certificado incluindo todos os hosts configurados no `.env`.

3.  **Isolamento de EntryPoints**:
    - O **Traefik** é configurado para não expor portas WAN (`44000`, `44300`) por padrão.
    - Apenas IngressRoutes que explicitamente solicitam esses EntryPoints são expostos externamente, prevenindo vazamento acidental de serviços internos.

## 🚀 Começando

### Pré-requisitos
- Docker
- macOS ou Linux
- `git`, `curl`
- (Opcional) `kind`, `helm`, `kubectl` (os scripts tentam instalar se necessário)

### 1. Configuração

Copie o template para um arquivo `.env` e personalize-o:

```bash
cp setup/.env.template setup/.env
nano setup/.env
```

**Variáveis Importantes:**
- `MEDIA_SERVERS_IN_CLUSTER`: `"true"` para rodar Plex/Emby no cluster, `"false"` (padrão) para rotear para instâncias externas.
- `MEDIA_PATH`: Caminho sua biblioteca de mídia no host.
- `DOWNLOADS_PATH`: Caminho para downloads no host.

### 2. Quick Start (Recomendado)

O script `init.sh` automatiza todo o processo: cria os clusters, configura a infraestrutura e faz o deploy das aplicações.

```bash
./setup/init.sh
```

### 3. Instalação Manual (Passo a Passo)

Se preferir rodar etapa por etapa:

**Passo 1: Bootstrap dos Clusters (Infra & Media)**
```bash
./setup/k8s/setup.sh
```
Isso roda `01-cluster-infra.sh` (cria infra e instala DNS) e `02-cluster-media.sh` (cria media cluster).

**Passo 2: Deploy das Aplicações de Mídia**
```bash
./setup/k8s/apply-media.sh
```

## 🛠️ Gerenciamento

- **Aplicar Manifesto**:
  ```bash
  # Media Cluster (Padrão)
  ./setup/k8s/apply.sh <arquivo.yaml>

  # Infra Cluster
  ./setup/k8s/apply.sh <arquivo.yaml> "$INFRA_CLUSTER_NAME"
  ```
- **Verificar Pods**:
  ```bash
  kubectl get pods -n media --context kind-media-cluster
  kubectl get pods -n infra --context kind-infra-cluster
  ```

## 🧹 Unload / Destruição

Para destruir os ambientes (graceful shutdown):

- **Destruir TUDO**:
  ```bash
  ./setup/k8s/unload.sh
  ```
- **Destruir apenas Media**: `./setup/k8s/unload-media.sh`
- **Destruir apenas Infra**: `./setup/k8s/unload-infra.sh`

## 🧩 Funcionalidades

- **DNS Resiliente**: DNS separado em cluster dedicado.
- **Deploy Condicional**: Plex/Emby dentro ou fora do cluster.
- **Automação Completa**: Scripts idempotentes para setup e teardown.
- **Integração Desktop**: Ajustes automáticos de PF (Packet Filter) no macOS para roteamento de rede.
- **Isolamento de EntryPoints**: Serviços internos protegidos contra exposição acidental na WAN.
- **Roteamento Split-Horizon**: Resolução de DNS interna otimizada com Bind9.

## 🧪 Testes & Verificação

Scripts e manifestos utilitários para validar a saúde do cluster:

- **Monitor de Conectividade**:
    - `setup/k8s/media/03-apps/99-test-connectivity.yaml.disabled`
    - Remove o sufixo `.disabled` e aplique para criar um pod que monitora a latência interna e externa e plota gráficos em tempo real.
- **Servidor de Teste Local**:
    - `setup/k8s/media/03-apps/99-test-local-server.yaml.disabled`
    - Um serviço Nginx simples (Whoami style) para validar regras de roteamento e IngressRoutes complexos.
