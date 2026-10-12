pipeline {
    agent any

    // 对应 Jenkins「系统管理 -> 工具」里配置的 Maven 安装名
    tools {
        maven 'maven3'
    }

    environment {
        DEPLOY_DIR = '/opt/app'
        IMAGE_NAME = 'helloworld'
    }

    parameters {
        booleanParam(
            name: 'DO_RELEASE',
            defaultValue: false,
            description: '勾选后执行 Maven Release：打 tag + 升 SNAPSHOT + push 回 GitHub（需先在 Jenkins 配好 github-token 凭据）'
        )
    }

    stages {
        // 真正的 git 检出：整条流水线基于 git，工作区自带 .git，方便后续发版提交/push
        stage('同步代码') {
            steps {
                checkout([$class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/guosgbin/cd_learn.git',
                        credentialsId: 'github-token'
                    ]]])
            }
        }

        stage('编译打包') {
            steps {
                // -B 非交互、-ntp 不下载进度条；本地仓库放 jenkins_home 以便持久化
                sh 'mvn -B -ntp -DskipTests -Dmaven.repo.local=/var/jenkins_home/.m2/repository clean package'
                // 复制到工作区根目录，便于传输（通配版本号，SNAPSHOT 变化也不怕）
                sh 'cp target/helloworld-*.jar helloworld.jar'
            }
        }

        // 串行 + 逐台人工确认：用循环遍历机器清单，每台部署前 input 卡一道
        stage('逐台确认并部署') {
            steps {
                script {
                    // ===== 目标机清单：以后新增机器，只需往这个列表加一项 =====
                    // name: 展示名；ssh: 登录地址（Jenkins 容器内用 host.docker.internal 指向宿主机）
                    // port: 该机器映射出来的 SSH 端口
                    def servers = [
                        [name: 'server-1', ssh: 'root@host.docker.internal', port: '2221'],
                        [name: 'server-2', ssh: 'root@host.docker.internal', port: '2222'],
                        // [name: 'server-3', ssh: 'root@host.docker.internal', port: '2223'],
                    ]
                    // =====================================================
                    // 保留 server-deploy-key（SSH 私钥凭据），用 sshUserPrivateKey 绑定导出私钥文件
                    // 避开 sshagent 的凭据类型绑定 bug；凭据类型无需改动
                    withCredentials([sshUserPrivateKey(credentialsId: 'server-deploy-key',
                                                       keyFileVariable: 'SSH_KEY',
                                                       usernameVariable: 'SSH_USER')]) {
                        for (s in servers) {
                            // 逐台串行 + 人工确认，点“部署”才发这一台
                            input message: "确认部署到 ${s.name} (${s.ssh}:${s.port})？", ok: '部署'
                            deployServer(s.ssh, s.port, env.DEPLOY_DIR, env.IMAGE_NAME, env.SSH_KEY)
                        }
                    }
                }
            }
        }

        // 发版（可选）：勾 DO_RELEASE 才执行
        // 1) git checkout -B main：Jenkins 检出是 detached HEAD，release 插件探测不到分支，必须先挂回 main
        // 2) 把 origin 换成带 token 的 URL：release:prepare 要 push tag 和升级 commit，需要凭据
        stage('发版 Maven Release') {
            when { expression { params.DO_RELEASE } }
            steps {
                withCredentials([string(credentialsId: 'github-token', variable: 'GT')]) {
                    sh '''
                        git config user.email "ci@local"
                        git config user.name "jenkins"
                        git checkout -B main
                        # release 插件打 tag 时直接读 pom 里的 scm 地址(裸 https)，不认 origin，
                        # 故用 insteadOf 把任意 https://github.com/ 自动补上 token，确保 push 带鉴权
                        git config url."https://x-access-token:${GT}@github.com/".insteadOf "https://github.com/"
                        # 清掉上一次失败残留，避免 release 误“续跑”
                        rm -f release.properties pom.xml.releaseBackup
                        mvn -B -ntp -Dmaven.repo.local=/var/jenkins_home/.m2/repository release:prepare -Darguments=-DskipTests
                    '''
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
// keyFile 为 withCredentials 导出的临时私钥文件，ssh/scp 均用 -i 指定
def deployServer(String sshHost, String port, String deployDir, String imageName, String keyFile) {
    sh """
set -e
ssh -o StrictHostKeyChecking=no -i ${keyFile} -p ${port} ${sshHost} 'mkdir -p ${deployDir}'
scp -o StrictHostKeyChecking=no -i ${keyFile} -P ${port} helloworld.jar Dockerfile ${sshHost}:${deployDir}/
ssh -o StrictHostKeyChecking=no -i ${keyFile} -p ${port} ${sshHost} '
set -e
cd ${deployDir}
docker build -t ${imageName}:latest .
docker rm -f ${imageName} 2>/dev/null || true
docker run -d --name ${imageName} -p 8080:8080 ${imageName}:latest
docker image prune -f
'
"""
}
