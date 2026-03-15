# 🐳 Tomcat Docker + AWS EKS Demo

**Free step-by-step demo** for learning containers, Docker, and Kubernetes from scratch.  
Perfect for anyone who wants to dockerize Tomcat apps and run them on EKS.

Created as a completely free demo — try it, learn the basics, then we can move to your real apps.

---

## 1. Prerequisites (install once)

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [AWS CLI](https://aws.amazon.com/cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools)
- (Optional) [eksctl](https://eksctl.io) for easy cluster creation

---

## 2. Dockerize a Tomcat App

Create a folder called `tomcat-demo` on your laptop.

**Create file: `Dockerfile`** (no extension) and paste this:

```dockerfile
FROM tomcat:10-jdk17-temurin

# Simple demo page (replace later with your real .war file)
RUN echo '<html><body><h1>✅ Hello from Dockerized Tomcat!</h1><p>This is running inside a container. Ready for EKS!</p></body></html>' > /usr/local/tomcat/webapps/ROOT/index.html

EXPOSE 8080
```

Run these commands inside the folder:

```bash
docker build -t tomcat-demo:v1 .
docker run -d -p 8080:8080 --name demo tomcat-demo:v1
```

Open browser → **http://localhost:8080**  
You should see the green hello page. ✅ Containerization done!

---

## 3. Push to AWS ECR

Replace `YOUR-AWS-ACCOUNT-ID` and region with yours.

```bash
# Create repo (one time)
aws ecr create-repository --repository-name tomcat-demo --region us-east-1

# Login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR-AWS-ACCOUNT-ID.dkr.ecr.us-east-1.amazonaws.com

# Tag & push
docker tag tomcat-demo:v1 YOUR-AWS-ACCOUNT-ID.dkr.ecr.us-east-1.amazonaws.com/tomcat-demo:v1
docker push YOUR-AWS-ACCOUNT-ID.dkr.ecr.us-east-1.amazonaws.com/tomcat-demo:v1
```

---

## 4. Deploy on AWS EKS

### Quick test cluster (paid AWS resources)

> Note: This example EKS cluster **is not free-tier**. Both the EKS control plane and the `t3.medium` worker nodes incur charges while the cluster exists. Check the latest AWS pricing and consider smaller instance types (e.g., `t3.small`/`t3.micro`) or a local Kubernetes option (kind/minikube) if you want to avoid AWS costs.

```bash
eksctl create cluster --name demo-eks --region us-east-1 --nodes 2 --node-type t3.medium
```
(After testing, delete with `eksctl delete cluster --name demo-eks` to avoid ongoing charges.)

### Kubernetes files (create these in the same folder):

**deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tomcat-demo
  template:
    metadata:
      labels:
        app: tomcat-demo
    spec:
      containers:
      - name: tomcat
        image: YOUR-AWS-ACCOUNT-ID.dkr.ecr.us-east-1.amazonaws.com/tomcat-demo:v1
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
```

**service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: tomcat-demo-service
spec:
  selector:
    app: tomcat-demo
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

**ingress.yaml** (optional for custom domain + HTTPS via AWS ALB)
> Prerequisite: This Ingress example assumes the [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) is already installed and configured in your cluster (OIDC provider, IAM role, and Helm chart). If you don't have it, skip `ingress.yaml` and just use `service.yaml` with `type: LoadBalancer`.
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tomcat-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tomcat-demo-service
            port:
              number: 80
```

Apply them (if you created `ingress.yaml`, apply all three files; otherwise just `deployment.yaml` and `service.yaml`):
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

Check:
```bash
kubectl get svc tomcat-demo-service
```
Open the **External-IP** in browser — your app is live on EKS! 🎉

---

## Health Checks & Resource Limits Explained
- **Readiness Probe** → Pod only receives traffic when ready.
- **Liveness Probe** → Restarts pod if it crashes.
- **Resources** → Prevents one pod from crashing the whole cluster (must-have in production).

---
