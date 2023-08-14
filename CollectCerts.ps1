<#
.SYNOPSIS
    This script connects to a TLS port and saves the server certificate(s) as .crt files to disk.

.DESCRIPTION
    The 'CollectCerts.ps1' script establishes a connection to the specified server using either the default port 636 (LDAPS) or alternatively a custom port can be specified.

.PARAMETER Server
    Specifies the name or IP address of the server to connect to. A DC in the target network is probably a good target.

.PARAMETER Port
    Specifies the port number to use for the connection. The default value is 636 (LDAPS) if not specified.

.EXAMPLE
    .\CollectCerts.ps1 -Server DC1.ad.bitsadmin.com
    
    Description:
    Connect to the LDAPS port of DC1 and save the certificates

.EXAMPLE
    .\CollectCerts.ps1 -Server 10.0.10.56 -Port 443
    
    Description:
    Connect to the HTTPS port of host 10.0.10.56 and save the certificates
#>
param ([Parameter(Mandatory)]$Server, [int]$Port=636)

try {
	# Create a TCP client connection to the server
	$tcpClient = New-Object System.Net.Sockets.TcpClient($Server, $Port)

	# Create an SslStream object to establish a secure connection
	$sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream())

	# Authenticate and establish a secure connection
	$sslStream.AuthenticateAsClient($Server)

	# Get the server's certificate chain
	$remoteCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]$sslStream.RemoteCertificate
	$certificateChain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
	$certificateChain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
	$certificateChain.Build($remoteCertificate) | Out-Null
	$certificates = $certificateChain.ChainElements

	# Iterate through each certificate in the chain
	foreach ($cert in $certificates) {
		# Get the certificate's encoded data
		$certData = $cert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)

		# Generate a unique filename for the certificate
		$fileName = "Cert_{0}.crt" -f $cert.Certificate.Subject.Replace('CN=','').Replace(', DC=','.')

		# Save the certificate as a .crt file
		$certData | Set-Content -Path $fileName -Encoding Byte

		Write-Host "Certificate saved: $fileName"
	}
}
finally {
	# Close the SSL stream and TCP client connection
	$sslStream.Dispose()
	$tcpClient.Close()
}