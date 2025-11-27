Day 75 
Maven and introduction to tomcat deployment 
Learned about Maven for project management and build automation, and an introduction to deploying applications on Apache Tomcat server. 

Jenkins:

Slave/Node: SSH and Username Method
Then, offload the work to newly launched ec2 instance..

1. Create a directory in new Node (under "var" directory) and add permisisons (chmod 777 remotedir) use at "remote root directory".

2. Install "java" and "git" in node/slave.

3. while adding a new node.. Add label "dev-node" "uat-name".. usage "build that match label expression".. 
launch via ssh --> add cred --> SSH --> GLobal --> "ec2-user" and Privatekey and add keyapir
Not verifying host strategy..

4. Now try to create or trigger an existing job and verify where its running..

5. Create a new item and choose "restrict where this can run" add ‘dev-label’ and test it.. 


——————————

Slave/Node: Username and Password Method

1. Install "java" and "git" in node/slave.
2.Create a directory in new Node (under "var" directory) and add permisisons (chmod 777 remotedir) use at "remote root directory".
3.Create username and password

useradd kiran
passwd kiran. (Password for username kiran), it will ask new password two times, enter same and confirm

4.Add this user in ‘wheel’ group and give the permission in ‘ssh_config’ as ‘Authorization’ yes

sudo usermod -aG wheel kiran

And give ‘PasswordAuthentication’ set ‘yes’ in sshd_config file
sudo vim /etc/ssh/sshd_config 
sudo systemctl restart sshd
 
sudo usermod -aG wheel newuser

Switch to new user: su kiran

 /home/kiran/newjenkins

——————————————
MAVEN INSTALL:
Apache Maven Install in EC2 instance:


1.Install the Java

dnf install java-21-amazon-corretto -y

2.Download and install the maven
Link: https://maven.apache.org/download.cgi
Url: https://dlcdn.apache.org/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz

Go to cd /opt
Download above file

3. Extract the file apache file
tar -xvf apache-maven-3.9.11-bin.tar.gz
sudo mv apache-maven-3.9.11 /opt/

4.This command sets the Maven home directory and makes it available system-wide for the current shell session.

export
	•	export makes the variable available to all child processes (sub-shells, applications, scripts).
	•	Without export, the variable only exists in the current shell session.
M2_HOME
	•	This is the environment variable name.
	•	By convention, M2_HOME is used to specify the installation directory of Apache Maven.

echo 'export M2_HOME=/opt/maven' >> ~/.bashrc
echo 'export PATH=$PATH:$M2_HOME/bin' >> ~/.bashrc
Or
sed -i '$ a export M2_HOME=/opt/maven' ~/.bashrc
sed -i '$ a export PATH=$PATH:$M2_HOME/bin' ~/.bashrc


export M2_HOME=/opt/apache-maven-3.9.11

5.This command adds Maven’s executable folder to your PATH so you can run mvn globally.

Part	Meaning
export	Makes the variable available to child processes.
PATH=	Defines the PATH environment variable.
$PATH	Keeps the existing PATH values.
:	Separator between directories in PATH.
$M2_HOME/bin	Adds Maven’s bin directory to the PATH so you can run mvn from anywhere.
export PATH=$M2_HOME/bin:$PATH

6.source reloads your shell configuration file without requiring you to log out or open a new terminal.
source ~/.bashrc

mvn archetype:generate

Debug Mode for Verbose Output: use -X or --debug
mvn -X validate

Redirecting Output to a File:
To save the entire console output, including logs, to a file instead of displaying it in the terminal, use the -l or --log-file option:
mvn --log-file ./mvn_validate.log validate
mvn validate > ./mvn_validate.log

Maven Goals:
mvn validate 
mvn compile
mvn test 
mvn package 
mvn verify
mvn clean install (if this run, then earlier all command will be run automatically)
 
groupid : mydemo proj
artifact: avinash
package : mydemo

—————————————

TOMCAT APACHE Installation:
Download: https://tomcat.apache.org/download-10.cgi

cd /opt/apache-tomcat-10.1.49/bin
sh startup.sh
The tomcat will run

ln -s /opt/apache-tomcat-10.1.49/bin/startup.sh /usr/bin/tomcatstart
ln -s /opt/apache-tomcat-10.1.49/bin/shutdown.sh /usr/bin/tomcatstop  


find / -name context.xml

vim /opt/apache-tomcat-10.1.49/webapps/host-manager/META-INF/context.xml
vim /opt/apache-tomcat-10.1.49/webapps/manager/META-INF/context.xml


“
You are not authorized to view this page. If you have not changed any configuration files, please examine the file conf/tomcat-users.xml in your installation. That file must contain the credentials to let you use this webapp.

For example, to add the admin-gui role to a user named tomcat with a password of s3cret, add the following to the config file listed above.

<role rolename="admin-gui"/>
<user username="tomcat" password="s3cret" roles="admin-gui"/>


Got to here: [root@ip-172-31-33-203 conf]# pwd
/opt/apache-tomcat-10.1.49/conf

  Built-in Tomcat manager roles:
    - manager-gui    - allows access to the HTML GUI and the status pages
    - manager-script - allows access to the HTTP API and the status pages
    - manager-jmx    - allows access to the JMX proxy and the status pages
    - manager-status - allows access to the status pages only

  The users below are wrapped in a comment and are therefore ignored. If you
  wish to configure one or more of these users for use with the manager web
  application, do not forget to remove the <!.. ..> that surrounds them. You
  will also need to set the passwords to something appropriate.


<role rolename="manager-gui"/>
<role rolename="manager-script”/>
<role rolename="manager-jmx”/>
<role rolename="manager-status”/>
<role rolename="admin-gui”/>
<user username="tomcat" password=“Tomcat” roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui”/>


Test the brewers:
curl -u tomcat:Kiran http://35.154.130.137:8080/manager/html | head -20

# Remove environment variables
sed -i '/JAVA_HOME/d' ~/.bashrc
sed -i '/M2_HOME/d' ~/.bashrc
sed -i '/TOMCAT/d' ~/.bashrc
sed -i '/maven/d' ~/.bashrc
sed -i '/PATH=.*java/d' ~/.bashrc

# Reload
source ~/.bashrc

