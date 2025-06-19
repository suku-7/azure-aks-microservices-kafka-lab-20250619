# Model
## azure-aks-microservices-kafka-lab-20250618
https://labs.msaez.io/#/courses/cna-full/2c7ffd60-3a9c-11f0-833f-b38345d437ae/deploy-my-app-2024

## Azure AKS에 컨테이너화된 FE/BE 마이크로서비스를 Kafka 연동하여 배포하고 운영한 실습입니다.
- Azure AKS 클러스터에 Spring Boot 마이크로서비스(BE) 및 웹 프론트엔드(FE)를 배포했습니다.
- Docker 이미지 빌드부터 Helm을 통한 Kafka 설치, 그리고 Kubernetes YAML 파일을 이용한 서비스 배포 및 상호 연동을 실습했습니다.
- 이를 통해 클라우드 네이티브 환경에서의 애플리케이션 배포 및 운영 전반을 경험했습니다.
- (3회차) 복습하는 과정으로 도커에 올린 이미지는 동일하게 사용하였고, 20.249.207.185로 변경된 IP만 적용해서 az-aks 실습을 진행하였습니다.

## 사전 준비
Azure 계정 및 구독, Gitpod 워크스페이스, Spring Boot 애플리케이션 코드

![스크린샷 2025-06-19 095249](https://github.com/user-attachments/assets/1e8b103a-1ad3-4874-9093-15ba681f321f)
![스크린샷 2025-06-19 103210](https://github.com/user-attachments/assets/404d7ace-14b8-4f14-bd60-bd94a02d02d9)
![스크린샷 2025-06-19 103458](https://github.com/user-attachments/assets/b331ddf4-2a32-4164-aabd-06b66fb1f79d)
![스크린샷 2025-06-19 103612](https://github.com/user-attachments/assets/d82c2d1a-14c4-4276-9829-7f1203372c83)
![스크린샷 2025-06-19 103859](https://github.com/user-attachments/assets/c6bfd568-6546-4d2c-9709-311e8433f2f7)
![스크린샷 2025-06-19 103937](https://github.com/user-attachments/assets/e24eab01-7ef0-4535-adc2-69107abe13ba)
![스크린샷 2025-06-19 103940](https://github.com/user-attachments/assets/232d115a-e726-45b1-b1a3-17a9c74b9a34)
![스크린샷 2025-06-19 103943](https://github.com/user-attachments/assets/5c0b2056-26be-4384-aed1-a8f9af11fcab)

---

이 문서는 Azure Kubernetes Service (AKS) 클러스터 환경에 Spring Boot 기반의 마이크로서비스 백엔드와 웹 프론트엔드를 배포하고 Kafka를 연동하는 과정을 상세히 기록합니다.  
Gitpod을 개발 환경으로 활용하여 Docker 이미지 빌드, Helm을 통한 미들웨어 설치, 그리고 Kubernetes YAML 파일을 이용한 서비스 배포 및 관리를 실습합니다.  

Kubernetes 환경에서는 애플리케이션의 application.yml 설정 파일에서 Kafka와 같은 클러스터 내부 서비스에 접근할 때 IP 주소 대신 서비스 이름(Service Name)을 DNS처럼 활용합니다.  
예를 들어, my-kafka:9092는 my-kafka라는 서비스 이름을 통해 Kafka에 연결하며, Kubernetes의 내부 DNS가 자동으로 해당 서비스의 클러스터 IP로 바인딩을 처리합니다.  
이는 서비스 디스커버리를 간소화하는 Kubernetes의 핵심 기능입니다. 또한, 서버 애플리케이션에서 npm이나 Docker Hub처럼 설치 파일을 관리하는 Helm을 통해서 Kafka와 같은 복잡한 미들웨어를 클러스터에 쉽게 배포할 수 있으며,  
별도로 포트를 9092 등으로 명시적으로 띄우지 않아도 Helm 차트가 모든 설정을 자동화하여 동작합니다.  

## 실습 단계별 상세 설명

1. 애플리케이션 도커라이징 및 Docker Hub 푸시
- 각 Spring Boot 마이크로서비스(order, delivery, product, gateway)의 JAR 파일을 빌드하고 이를 Docker 이미지로 생성한 후 Docker Hub에 푸시합니다.
 이는 Kubernetes에 배포될 컨테이너 이미지를 준비하는 과정입니다.
```
# (필요시) Java SDK 설치/업그레이드
sdk install java

# Order 서비스 빌드 및 도커라이징
cd order
mvn package -B -Dmaven.test.skip=true
# (선택 사항: 로컬에서 JAR 파일 실행 확인) java -jar target/order-0.0.1-SNAPSHOT.jar
docker build -t sukuai/order:250617 .
docker images # 빌드된 이미지 확인
docker push sukuai/order:250617 # Docker Hub에 이미지 푸시
cd .. # 상위 디렉토리로 이동

# Delivery 서비스 빌드 및 도커라이징
cd delivery
mvn package -B -Dmaven.test.skip=true
# (선택 사항: 로컬에서 JAR 파일 실행 확인) java -jar target/delivery-0.0.1-SNAPSHOT.jar
docker build -t sukuai/delivery:250617 .
docker images
docker push sukuai/delivery:250617
cd ..

# Product 서비스 빌드 및 도커라이징
cd product
mvn package -B -Dmaven.test.skip=true
# (선택 사항: 로컬에서 JAR 파일 실행 확인) java -jar target/product-0.0.1-SNAPSHOT.jar
docker build -t sukuai/product:250617 .
docker images
docker push sukuai/product:250617
cd ..

# Gateway 서비스 빌드 및 도커라이징
cd gateway
mvn package -B -Dmaven.test.skip=true
# (선택 사항: 로컬에서 JAR 파일 실행 확인) java -jar target/boot-camp-gateway-0.0.1-SNAPSHOT.jar
docker build -t sukuai/gateway:250617 .
docker images
docker push sukuai/gateway:250617
cd ..
```
2. Azure CLI 로그인 및 AKS 클러스터 연동
- Azure 계정에 로그인하고 AKS 클러스터의 자격 증명(kubeconfig)을 가져와 kubectl 명령어가 해당 클러스터와 통신할 수 있도록 설정합니다.
```
# Azure CLI 설치 확인 (Gitpod 환경에는 보통 사전 설치되어 있음)
az --version

# Azure 계정 로그인 (브라우저를 통한 디바이스 코드 인증)
az login --use-device-code

# AKS 클러스터 자격 증명 가져오기 및 Kubectl 컨텍스트 설정
az aks get-credentials --resource-group a071098-rsrcgrp --name a071098-aks

# 현재 클러스터 리소스 및 노드 상태 확인
kubectl get all
kubectl get node

# (선택 사항) 이전에 배포된 특정 리소스가 있다면 삭제하여 초기화
# kubectl delete deploy order-by-yaml
# (일괄 삭제) kubectl delete deploy --all
# (일괄 삭제) kubectl delete svc --all
```
3. Helm 설치
- Kubernetes의 패키지 관리 도구인 Helm을 설치합니다. Helm은 복잡한 애플리케이션을 Kubernetes에 배포하고 관리하는 데 유용합니다.
```
# Helm 3.x 설치 스크립트 다운로드 및 실행 (Linux 환경 기준)
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```
4. Kafka 클러스터에 배포
- Helm을 사용하여 Bitnami Kafka 차트를 통해 Kafka 서버를 AKS 클러스터에 배포합니다. Helm은 Kafka를 포함한 필요한 모든 Kubernetes 리소스(Deployment, Service 등)를 자동으로 생성합니다.
```
# Bitnami Helm 저장소 추가 및 업데이트
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Kafka 설치 (특정 버전 23.0.5 지정)
helm install my-kafka bitnami/kafka --version 23.0.5

# Kafka 설치 확인 (my-kafka 관련 Pod, Service, StatefulSet 등이 생성되었는지 확인)
kubectl get all
```
5. 마이크로서비스 배포 (YAML 파일 사용)
- 각 마이크로서비스(order, delivery, product, gateway)의 kubernetes 폴더 안에 있는 Deployment 및 Service YAML 파일을 클러스터에 적용합니다.
- deployment.yaml 파일 내 image: 경로를 본인이 Docker Hub에 푸시한 정확한 이미지명(sukuai/[서비스명]:250617)으로 반드시 수정해야 합니다.
- 이미지가 없거나 경로가 틀리면 ImagePullBackOff 오류가 발생합니다. 배포 후 파드가 Running 상태인지, 서비스가 제대로 연결되었는지 확인합니다.
```
# Order 서비스 배포
cd order
# (필수) kubernetes/deployment.yaml 파일 내 'image: sukuai/order:250617'로 수정 필요
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl get all # 배포된 order Deployment, Service, Pod 상태 확인
cd ..

# Delivery 서비스 배포
cd delivery
# (필수) kubernetes/deployment.yaml 파일 내 'image: sukuai/delivery:250617'로 수정 필요
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl get all # 배포된 delivery Deployment, Service, Pod 상태 확인
cd ..

# Product 서비스 배포
cd product
# (필수) kubernetes/deployment.yaml 파일 내 'image: sukuai/product:250617'로 수정 필요
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl get all # 배포된 product Deployment, Service, Pod 상태 확인
cd ..

# Gateway 서비스 배포
cd gateway
# (필수) kubernetes/deployment.yaml 파일 내 'image: sukuai/gateway:250617'로 수정 필요
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl get all # 배포된 gateway Deployment, Service, Pod 상태 확인
cd ..
```
6. 서비스 동작 확인 및 API 테스트
- 모든 마이크로서비스가 정상적으로 배포되었는지 kubectl 명령어로 확인하고, Gateway 서비스의 외부 IP를 통해 API 호출을 수행하여 엔드-투-엔드(end-to-end) 동작을 검증합니다.
```
# 모든 서비스 및 파드의 현재 상태 확인
kubectl get svc
kubectl get po

# Gateway 서비스의 External IP 주소 확인 (예시 IP: 24.230.153.146)
# service/gateway        LoadBalancer   10.0.28.176    4.230.153.146   8080:31664/TCP

# 재고 생성 API 호출 (httpie 툴 사용)
http 4.230.153.146:8080/inventories id=1 stock=100

# 주문 생성 API 호출 (이벤트 발생 및 재고 차감 확인)
http 4.230.153.146:8080/orders productId=1 productName="TV" qty=3

# 재고 및 주문 목록 다시 확인 (데이터 변화 확인: 예. 재고 100개 -> 97개)
http 4.230.153.146:8080/inventories
http 4.230.153.146:8080/orders
```
7. Kafka 이벤트 확인 및 클라이언트 사용
- 임시 Kafka 클라이언트 파드를 생성하여 Kafka 토픽에 발행된 메시지를 직접 소비하고 확인합니다. 이는 Kafka 연동이 제대로 되는지 검증하는 유틸리티성 작업입니다.
```
# 임시 Kafka 클라이언트 파드 생성 (재시작하지 않는 일회성 파드)
kubectl run my-kafka-client --restart='Never' --image docker.io/bitnami/kafka:3.5.0-debian-11-r21 --namespace default --command -- sleep infinity
kubectl get all # my-kafka-client 파드가 생성되었는지 확인

# Kafka 클라이언트 파드 쉘 접속
kubectl exec --tty -i my-kafka-client --namespace default -- bash

# Kafka 컨슈머 실행 (my-kafka.default.svc.cluster.local:9092는 클러스터 내부 Kafka 서비스 DNS)
kafka-console-consumer.sh --bootstrap-server my-kafka.default.svc.cluster.local:9092 --topic modelforops --from-beginning
# (다른 터미널에서 주문 생성 등 이벤트를 발생시키면 이 터미널에서 메시지 확인 가능)
# (컨슈머 종료: Ctrl+C 입력 후 'exit' 명령어로 쉘 종료)
```
8. 문제 해결 및 고급 테스트
- Kubernetes 환경에서 발생할 수 있는 일반적인 문제 해결 방법과 고급 기능(자체 복구, 스케일링)을 테스트합니다.
- kubectl get all 명령 시 replicaset.apps/order-fdc45f5f6처럼 DESIRED, CURRENT, READY가 모두 0으로 표시되는 ReplicaSet은 이전 버전의 파드를 관리하던 것으로,
- Deployment의 롤링 업데이트 과정에서 새로운 ReplicaSet으로 교체되어 더 이상 활성화된 파드가 없는 정상적인 상태입니다. 불필요하다고 판단되면 삭제할 수 있습니다.
```
# 파드 자체 복구 테스트 (Kubernetes의 자가 치유 능력 확인)
# 새 터미널 1: watch kubectl get po # 파드 상태 실시간 감시
# 새 터미널 2: kubectl delete po --all # 모든 파드 강제 종료
kubectl get po # 잠시 후 파드가 다시 생성되었음을 확인

# Deployment 스케일링 (주문 서비스 파드를 3개로 확장하여 부하 분산 테스트)
kubectl scale deploy order --replicas=3
kubectl get po # order Deployment에 의해 3개의 파드가 생성되었는지 확인 (선별적 확장이 가능함)

# 특정 파드의 상세 정보 확인 (Pod 이름은 kubectl get po로 확인)
kubectl describe po <pod-name>

# 특정 파드의 실시간 로그 확인 (Pod 이름 필요)
kubectl logs -f <pod-name>

# 비활성화된 ReplicaSet의 과거 정보 확인
kubectl describe replicaset order-fdc45f5f6
# (선택 사항) 비활성화된 ReplicaSet 삭제
# kubectl delete replicaset order-fdc45f5f6

# External IP로 접속이 되지 않는 경우 (로컬 환경에서 임시 포트 포워딩)
# 새 터미널 1:
# kubectl port-forward svc/order 8080:8080 # 로컬 8080포트를 클러스터 order 서비스의 8080포트로 연결
# 새 터미널 2:
# curl localhost:8080 # 로컬에서 서비스 접속 테스트

# (전체 재배포 필요 시) 기존 쿠버네티스 객체들을 제거하여 초기화
# kubectl delete deploy --all
# kubectl delete svc --all
```
9. 프론트엔드 배포 및 도커라이징
- 웹 프론트엔드 프로젝트를 빌드하고 Docker 이미지로 만든 후, Kubernetes에 배포합니다. 빌드된 정적 파일(dist 폴더 내용)은 webratio/nodejs-http-server와 같은 경량 웹 서버를 포함하는 컨테이너에 복사되어 서비스됩니다.
```
# Frontend 프로젝트 빌드 (Gitpod 환경에서 실행)
cd frontend/
npm install   # 프로젝트 의존성 설치
npm run serve # (선택 사항: 로컬에서 개발 서버 실행 확인)
# (확인 후 Ctrl+C로 종료)
npm run build # 프로덕션용 정적 파일 빌드 (dist/ 폴더에 결과물 생성)

# Frontend Docker 이미지 빌드
# (Dockerfile은 dist/ 폴더의 정적 파일들을 웹 서버 컨테이너에 복사)
docker build -t sukuai/frontend:250617 .
docker push sukuai/frontend:250617 # Docker Hub에 이미지 푸시
cd .. # 상위 디렉토리로 이동

# Frontend Deployment 및 Service YAML 파일 수정 및 적용
# frontend/kubernetes/deployment.yaml 파일 내 'image: sukuai/frontend:250617'로 수정
kubectl apply -f frontend/kubernetes/deployment.yml
kubectl apply -f frontend/kubernetes/service.yaml

# 프론트엔드 배포 확인
kubectl get all

# 웹 UI 테스트 (Gateway 서비스의 External IP 주소로 접속)
# 예시: http://4.230.153.146:8080/#/
```
