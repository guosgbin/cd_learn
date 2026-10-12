pipeline {
    agent any

    // 对应 Jenkins「系统管理 -> 工具」里配置的 Maven 安装名
    tools {
        maven 'maven3'
    }

    environment {
        // 两台目标机（Jenkins 容器内用 host.docker.internal 指向宿主机）
        SERVER1_SSH = 'root@host.docker.internal'
        SERVER2_SSH = 'root@host.docker.internal'
        SERVER1_PORT = '2221'
        SERVER2_PORT = '2222'
        DEPLOY_DIR = '/opt/app'
        IMAGE_NAME = 'helloworld'
    }

    stages {
        stage('同步代码') {
            steps {
                // 把宿主机挂载进来的源码复制到构建工作区（排除本地 target 和 servers）
                sh 'tar -C /src --exclude=./target --exclude=./servers -cf - . | tar -xf -'
            }
        }

        stage('编译打包') {
            steps {
                // -B 非交互、-ntp 不下载进度条；本地仓库放 jenkins_home 以便持久化
                sh 'mvn -B -ntp -DskipTests -Dmaven.repo.local=/var/jenkins_home/.m2/repository package'
                // 复制到工作区根目录，便于传输
                sh 'cp target/helloworld-1.0.0.jar helloworld.jar'
            }
        }

        stage('部署到两台服务器') {
            steps {
                script {
                    // 与团队一致：用 sshagent 注入私钥，裸 ssh/scp 远程执行
                    sshagent(credentials: ['server-deploy-key']) {
                        parallel(
                            'server-1': {
                                deployServer(env.SERVER1_SSH, env.SERVER1_PORT, env.DEPLOY_DIR, env.IMAGE_NAME)
                            },
                            'server-2': {
                                deployServer(env.SERVER2_SSH, env.SERVER2_PORT, env.DEPLOY_DIR, env.IMAGE_NAME)
                            }
                        )
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'helloworld.jar', fingerprint: true
        }
    }
}

// 部署函数：建目录 -> scp jar+Dockerfile -> 远端 docker build & run
def deployServer(String sshHost, String port, String deployDir, String imageName) {
    sh """
set -e
ssh -o StrictHostKeyChecking=no -p ${port} ${sshHost} 'mkdir -p ${deployDir}'
scp -o StrictHostKeyChecking=no -P ${port} helloworld.jar Dockerfile ${sshHost}:${deployDir}/
ssh -o StrictHostKeyChecking=no -p ${port} ${sshHost} '
set -e
cd ${deployDir}
docker build -t ${imageName}:latest .
docker rm -f ${imageName} 2>/dev/null || true
docker run -d --name ${imageName} -p 8080:8080 ${imageName}:latest
docker image prune -f
'
"""
}
