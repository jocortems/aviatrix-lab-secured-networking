#!/bin/bash
apt update
cat > /usr/local/share/ca-certificates/dcfca.crt <<EOF
-----BEGIN CERTIFICATE-----
MIID3TCCAsWgAwIBAgIUBaOH7PxKlOpN5Zzc3m2sx8yknP4wDQYJKoZIhvcNAQEL
BQAwfjELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAlRYMQ8wDQYDVQQHDAZBVVNUSU4x
DDAKBgNVBAoMA0NTRTEMMAoGA1UECwwDRENGMRAwDgYDVQQDDAdjc2Uub3JnMSMw
IQYJKoZIhvcNAQkBFhRqY29ydGVzQGF2aWF0cml4LmNvbTAeFw0yMzA3MTMwMDM0
NTJaFw00MzA3MDgwMDM0NTJaMH4xCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJUWDEP
MA0GA1UEBwwGQVVTVElOMQwwCgYDVQQKDANDU0UxDDAKBgNVBAsMA0RDRjEQMA4G
A1UEAwwHY3NlLm9yZzEjMCEGCSqGSIb3DQEJARYUamNvcnRlc0BhdmlhdHJpeC5j
b20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCpgz205kVvLUDcYWS8
gm5nCtHnzfVno3N/ABf9UZFcQTTPeKOUbW1GoSq7750KXBeXPoBp4h5AWxc4gptM
hRDgFWcWq3BzElYADGAMXyZX2FsnIXc++aOGj9XEpO3/BajKr4pVQ/k4vb9UUmkZ
MtNB1+CnGWOaxFKglqv6AfgL7HQqvyCtfmXegW0KyIDOMguGst6o1DJacK7TzawA
iUi3MuIh9ew3t5SBWORJVNG9YSf7QOokGq+/dOv77nS/qmm6zP3qT4UCdFL0NJOW
+rKj7GVclwQze3m9bVjXVNhIgeq566Vuoo03D2bPj4TIoOCzh2wfHmlbhz7P9tMM
kTbBAgMBAAGjUzBRMB0GA1UdDgQWBBQdzmR4FruxH1dOrGe0/fVXm14x3TAfBgNV
HSMEGDAWgBQdzmR4FruxH1dOrGe0/fVXm14x3TAPBgNVHRMBAf8EBTADAQH/MA0G
CSqGSIb3DQEBCwUAA4IBAQBWNjGUFdfCOq73VL+vb1T1zaNZbxLXG7qC6PTwVelg
DX48luNl6sDbLIp72KX3RW75Q1etCdHfH4nc7k2ASxPG841hAcBCj1HIKmA+xAUf
xdavHrb4G6fwSEVXwE7UgVIgfJO+HuqjenxC46Wq7zyhxommLLFI7tWSpS9HMblk
/gxJ3TaMKr+8HRhzge+IF7j025lrr4oxQ6NynMZzhcucfvzTJFCUVXw24saCiF7a
rdGjVK0s7wf9i/UCk2L/fjuDIM0DlP1wnBuc2EcRzRVn0iuz+qiIuYyVPS5+AgqB
r80oboj11b9Di5QbI5TFZob2/UAYbBRKjOEM5/2gAvnr
-----END CERTIFICATE-----
EOF

cat > /usr/local/share/ca-certificates/dcfintermediate.crt <<EOF
-----BEGIN CERTIFICATE-----
MIID0TCCArmgAwIBAgICEAAwDQYJKoZIhvcNAQELBQAwfjELMAkGA1UEBhMCVVMx
CzAJBgNVBAgMAlRYMQ8wDQYDVQQHDAZBVVNUSU4xDDAKBgNVBAoMA0NTRTEMMAoG
A1UECwwDRENGMRAwDgYDVQQDDAdjc2Uub3JnMSMwIQYJKoZIhvcNAQkBFhRqY29y
dGVzQGF2aWF0cml4LmNvbTAeFw0yMzA3MTMwMDQwNTlaFw0zMzA3MTAwMDQwNTla
MHExCzAJBgNVBAYTAlVTMQswCQYDVQQIDAJUWDEMMAoGA1UECgwDQ1NFMQwwCgYD
VQQLDANEQ0YxFDASBgNVBAMMC2RjZi5jc2Uub3JnMSMwIQYJKoZIhvcNAQkBFhRq
Y29ydGVzQGF2aWF0cml4LmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBAMBXa9XiQ1PXuZL3UBOClW8zdzAJJift9x3+0QJX6WDrHcKPtPt93ypD5QUF
3qCiAC5XnkFulKsiAjTY3pgevLDg35tXmlmO00mm/HSs26rWRFdFHbMRaU6Y6Lgb
cCDNDA9w4+xuZIUiHQdDL/NbiF8/appTaSEGV2q7ONH8zzsakcTr1muoJFDm1pYN
tkNwpgTNPYwAtg86g4c6yIraW1NiYkUDAILRYpTf5wkh4/aF+m1HRfGGSTMWRxMs
rokzjsiCJh7DB20I+5wVVuyn3X8S1IOfazCH/yODhZMITefj7QQj0sdDwAwkyaIA
ezQNXM48huhvTn/1CnlxihlhupMCAwEAAaNmMGQwHQYDVR0OBBYEFEhkHGu9sklp
39Z6vlVl+ugmE016MB8GA1UdIwQYMBaAFB3OZHgWu7EfV06sZ7T99VebXjHdMBIG
A1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEBCwUA
A4IBAQACumOqKIs77I2KYri3jrcectLyZ/PcNUwphHdPedxVEXaXw7Ezl6vpbaZj
s3mXHyONwbzoLyXZR7CL3ST+L22pFY/bYSZBXOgM6MrTgxHZQeczZsaDnjK9gWWm
7bEaaiqSqpAPA0KXY5Cj6r/VJ+Rx/QsYRwFoq1sJhg88XEuUQaCN5FdSMHYpCbxt
JtHxNDFbz9z+KkCsVTWTJtiRt5JMNdzhpueqtkj2Upojo7AWbGXkRYw5B/v6dcYX
nsibPPk5rkgpk6fyd8EoXE8zPIBW24rN4N99qw08NEfyb6WDls5SDD/hdCw1nWBe
ShHp1VdQGhr6NQA54L9W2lXEFVis
-----END CERTIFICATE-----
EOF

update-ca-certificates
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
interface=$(ip -4 route list 0/0 | awk '{ print $5 }')
ip=$(ip -4 addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
octetb=$(echo $ip | cut -d. -f2)
octetc=$(echo $ip | cut -d. -f3)
octetd=$(echo $ip | cut -d. -f4)
octetsum=$((octetb + octetc + octetd))
brnet=$((octetsum % 256))
docker network create --subnet=192.168.$brnet.0/24 avxtestnet
docker run -d -p 8080:8080 --network=avxtestnet jorgecortesdocker/myipapp:v3
apt install -y tcpdump hping3 inetutils-traceroute tcptraceroute dnsutils netcat build-essential git apt-transport-https ca-certificates curl software-properties-common mtr nginx paris-traceroute
echo -e  "\n\r\t\033[32m***Welcome to $(hostname -I)on port 80***\033[0m\n\r" | tee /var/www/html/index.nginx-debian.html
git clone https://github.com/microsoft/ntttcp-for-linux.git
cd ntttcp-for-linux/src/
make
make install