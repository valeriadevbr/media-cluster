# Comandos Úteis Kubernetes (Kind / Nginx)

Guia rápido de comandos para gerenciamento do cluster de mídia.

## 1. Inspeção Básica (Consultas)

### Listar Recursos Principais
```bash
# Listar todos os pods no namespace 'media'
kubectl get pods -n media

# Listar todos os serviços e seus IPs internos
kubectl get svc -n media

# Listar ingressos (regras de acesso externo/DNS)
kubectl get ingress -n media

# Listar todos os recursos de uma vez
kubectl get all -n media
```

### Visualizar em Tempo Real (-w)
```bash
# Acompanhar a criação/mudança de pods
kubectl get pods -n media -w
```

## 2. Logs e Depuração

### Ver Logs de um Pod
```bash
# Logs atuais de um pod específico
kubectl logs -n media <nome-do-pod>

# Acompanhar logs em tempo real (tail -f)
kubectl logs -f -n media <nome-do-pod>

# Ver logs de um serviço usando label (mais fácil)
kubectl logs -f -n media -l app=plex

# Ver logs do pod anterior (útil se o container crashou)
kubectl logs -p -n media <nome-do-pod>
```

### Descrever Recursos (Problemas detalhados)
```bash
# Ver eventos e detalhes técnicos (por que o pod não sobe?)
kubectl describe pod -n media <nome-do-pod>
kubectl describe ingress -n media plex-ingress
```

## 3. Acesso aos Containers

### Abrir Terminal Interativo (Shell)
```bash
# Acessar o container do Plex
kubectl exec -it -n media deploy/plex -- /bin/bash

# Acessar o container do Emby
kubectl exec -it -n media deploy/emby -- /bin/sh
```

### Executar Comando Direto
```bash
# Listar arquivos dentro do volume montado no Sonarr
kubectl exec -n media deploy/sonarr -- ls -la /media
```

## 4. Gerenciamento de Deployments

### Reiniciar um Aplicativo (Sem downtime)
```bash
# Forçar o Kubernetes a recriar os pods de um serviço (bom para limpar cache/trava)
kubectl rollout restart deployment plex -n media
kubectl rollout restart deployment emby -n media
```

### Verificar Status do Rollout
```bash
kubectl rollout status deployment sonarr -n media
```

## 5. Ingress Nginx (Infraestrutura)

### Ver Logs do Controlador Nginx
```bash
kubectl logs -f -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Verificar Endereço IP do Cluster
```bash
# No Kind, geralmente o IP do control-plane
kubectl get nodes -o wide
```

## 6. Recursos do Sistema

### Ver Consumo de CPU/Ram
```bash
# Se o metrics-server estiver ativo
## 7. Acesso ao Dashboard

### Gerar Token de Acesso (Admin)
Para acessar o painel administrativo (Kubernetes Dashboard), é necessário um token de autenticação.
```bash
# Cria um token para o usuário admin (válido por 24 horas)
kubectl create token admin-user -n infra --duration=24h
```

## 8. Roadmap / Melhorias Futuras

Ideias para aprimorar o ambiente no futuro:

- [ ] **Páginas de Erro Customizadas (Nginx)**: Implementar um Custom Default Backend para exibir HTML personalizado em erros 404, 502, 503 e 504.
- [ ] **Monitoramento Avançado**: Instalar Prometheus/Grafana para visualizar o consumo real de cada pod no dashboard.
- [ ] **Real IP para Outros Apps**: Verificar se outros apps (além do Plex) precisam de reconhecimento de IP real para logs ou segurança.
