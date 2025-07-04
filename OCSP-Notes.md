## The Apache configuration is trying to use the SHMCB (shared memory cache) module for OCSP stapling, but we haven't loaded it.

### Troubleshooting steps

1. Identified the error in Apache logs showing missing SHMCB module for OCSP stapling cache
2. Added LoadModule directive in httpd.conf: `LoadModule socache_shmcb_module modules/mod_socache_shmcb.so`
3. Modified Dockerfile to enable the module in the base Apache configuration

### Evidence

The initial error logs showed that Apache was unable to start due to a missing module required for OCSP stapling:

```
Attaching to api, ocsp_responder, proxier
ocsp_responder  | [OCSP] Starting OpenSSL OCSP responder on port 8080
ocsp_responder  | + openssl ocsp -index index.txt -port 8080 -rsigner ocsp.crt -rkey ocsp.key -CA ca.crt -ignore_err -text
ocsp_responder  | ACCEPT [::]:8080 PID=1
ocsp_responder  | ocsp: waiting for OCSP client connections...
proxier         | AH00526: Syntax error on line 35 of /usr/local/apache2/conf/httpd.conf:
proxier         | SSLStaplingCache: 'shmcb' stapling cache not supported (known names: ) Maybe you need to load the appropriate socache module (mod_socache_shmcb?)
proxier exited with code 0
proxier exited with code 1
api             | INFO:     Started server process [1]
api             | INFO:     Waiting for application startup.
api             | INFO:     Application startup complete.
api             | INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
proxier exited with code 1
proxier exited with code 1
proxier exited with code 1
proxier exited with code 1
proxier         | AH00526: Syntax error on line 35 of /usr/local/apache2/conf/httpd.conf:
proxier         | SSLStaplingCache: 'shmcb' stapling cache not supported (known names: ) Maybe you need to load the appropriate socache module (mod_socache_shmcb?)
proxier exited with code 1
proxier exited with code 1
proxier exited with code 1
proxier exited with code 1
```

### Solution

The problem was that while we had configured OCSP stapling to use the SHMCB cache (`SSLStaplingCache shmcb:/var/run/ocsp(128000)`), we hadn't loaded the required Apache module that provides this functionality. Two changes were needed:

1. In `proxier/httpd.conf`, added the module load directive:
```
LoadModule socache_shmcb_module modules/mod_socache_shmcb.so
```

2. In `proxier/Dockerfile`, enabled the module in the base configuration:
```
RUN sed -i 's/#LoadModule socache_shmcb_module/LoadModule socache_shmcb_module/' /usr/local/apache2/conf/original/httpd.conf
```

### Result

After applying these changes, Apache started successfully with OCSP stapling enabled:

```
Attaching to api, ocsp_responder, proxier
ocsp_responder  | [OCSP] Starting OpenSSL OCSP responder on port 8080
ocsp_responder  | + openssl ocsp -index index.txt -port 8080 -rsigner ocsp.crt -rkey ocsp.key -CA ca.crt -ignore_err -text
ocsp_responder  | ACCEPT [::]:8080 PID=1
ocsp_responder  | ocsp: waiting for OCSP client connections...
proxier         | [Fri Jul 04 19:38:02.675124 2025] [ssl:warn] [pid 1:tid 1] AH01873: Init: Session Cache is not configured [hint: SSLSessionCache]
proxier         | [Fri Jul 04 19:38:02.712578 2025] [mpm_event:notice] [pid 1:tid 1] AH00489: Apache/2.4.63 (Unix) OpenSSL/3.5.1 configured -- resuming normal operations
proxier         | [Fri Jul 04 19:38:02.712602 2025] [core:notice] [pid 1:tid 1] AH00094: Command line: 'httpd -D FOREGROUND'
api             | INFO:     Started server process [1]
api             | INFO:     Waiting for application startup.
api             | INFO:     Application startup complete.
api             | INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

## Browser attempting plain HTTP connection to SSL-enabled port

### Error Message
```
Bad Request

Your browser sent a request that this server could not understand.
Reason: You're speaking plain HTTP to an SSL-enabled server port.
Instead use the HTTPS scheme to access this URL, please.
```

### Analysis
This error occurs because:
1. Apache is configured to listen on port 443 (HTTPS) only
2. When accessing via http://localhost, the browser attempts a plain HTTP connection
3. Apache's SSL-enabled port cannot handle plain HTTP requests

### Solution
We should add HTTP to HTTPS redirection in the Apache configuration. This requires:

1. Enable mod_rewrite module
2. Add a VirtualHost for port 80 (HTTP)
3. Add rewrite rules to redirect all HTTP traffic to HTTPS

Changes needed in `proxier/httpd.conf`:
```apache
# Add module
LoadModule rewrite_module modules/mod_rewrite.so

# Add HTTP port
Listen 80

# Add HTTP VirtualHost with redirect
<VirtualHost *:80>
    ServerName localhost
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>
```

Also need to update `docker-compose.yml` to expose port 80:
```yaml
ports:
  - "80:80"    # Add this line
  - "443:443"  # Existing HTTPS port
```

### Expected Result
After these changes:
1. HTTP requests to http://localhost will automatically redirect to https://localhost
2. Users get a smoother experience without seeing the "plain HTTP" error
3. HTTPS and OCSP stapling continue to work as before

## SSLStaplingCache directive must be in global configuration

### Error Message
```
AH00526: Syntax error on line 66 of /usr/local/apache2/conf/httpd.conf:
SSLStaplingCache cannot occur within <VirtualHost> section
```

### Analysis
The `SSLStaplingCache` directive, along with other global OCSP stapling configuration, must be placed outside of any `<VirtualHost>` sections in the Apache configuration. This is because the stapling cache is a server-wide resource that needs to be available to all virtual hosts.

### Solution
Move all OCSP stapling configuration to the global section of httpd.conf:

```apache
# Global SSL configuration
SSLStaplingCache shmcb:/var/run/ocsp(128000)
SSLUseStapling on
SSLStaplingResponderTimeout 5
SSLStaplingReturnResponderErrors off

<VirtualHost *:443>
    # Virtual host specific SSL settings only
    SSLEngine on
    SSLCertificateFile /etc/ssl/demo/server.crt
    SSLCertificateKeyFile /etc/ssl/demo/server.key
    SSLCertificateChainFile /etc/ssl/demo/ca.crt
    ...
</VirtualHost>
```

### Expected Result
Apache should now start successfully with OCSP stapling enabled and properly configured for all virtual hosts.

## Improved SSL and OCSP Stapling Configuration

### Analysis
The initial SSL and OCSP stapling configuration needed several improvements:
1. Global SSL settings were missing
2. Cache paths were pointing to potentially non-existent directories
3. SSL session cache was not configured
4. Modern SSL/TLS security settings were not enforced

### Solution
Added comprehensive SSL and OCSP stapling configuration in the global section:

```apache
# Global SSL Settings
SSLCipherSuite HIGH:!aNULL
SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
SSLHonorCipherOrder on
SSLSessionCache shmcb:/usr/local/apache2/logs/ssl_scache(512000)
SSLSessionCacheTimeout 300

# Global OCSP Stapling Settings
SSLUseStapling On
SSLStaplingCache shmcb:/usr/local/apache2/logs/ssl_stapling(512000)
SSLStaplingResponderTimeout 5
SSLStaplingReturnResponderErrors off
SSLStaplingFakeTryLater off
```

Key improvements:
1. Disabled old SSL/TLS versions (SSLv3, TLSv1, TLSv1.1)
2. Set secure cipher preferences
3. Configured SSL session cache for better performance
4. Moved cache files to Apache's logs directory
5. Added `SSLStaplingFakeTryLater` to ensure accurate stapling responses

### Expected Result
1. More secure SSL/TLS configuration
2. Better performance through session caching
3. More reliable OCSP stapling
4. Proper cache file locations

## Verification of Working State

### Evidence from Logs
The following log entries confirm that OCSP stapling is working correctly:

1. **Initial OCSP Response Fetch**:
```
[ssl:debug] ssl_util_stapling.c(819): AH01951: stapling_cb: OCSP Stapling callback called
[ssl:debug] ssl_util_stapling.c(495): AH01938: stapling_renew_response: querying responder
```

2. **OCSP Response Status**:
```
OCSP Response Data:
    OCSP Response Status: successful (0x0)
    Cert Status: good
```

3. **Stapling Cache Working**:
```
[ssl:debug] ssl_util_stapling.c(368): AH01933: stapling_get_cached_response: cache hit
```

4. **Secure TLS Configuration**:
```
Protocol: TLSv1.3, Cipher: TLS_AES_256_GCM_SHA384 (256/256 bits)
```

### Analysis
The logs show that:
1. Apache successfully queries the OCSP responder for certificate status
2. The OCSP responder confirms the certificate is valid
3. The response is cached and reused for subsequent requests
4. Modern TLS 1.3 with strong encryption is being used
5. The entire stack (API, OCSP responder, and Apache) is working together correctly

### Success Criteria Met
✅ OCSP stapling enabled and working
✅ Response caching functioning
✅ Strong TLS security (TLS 1.3)
✅ Automatic HTTPS redirection
✅ API accessible and responding

## FIPS Mode and Compliance

### What is FIPS?
FIPS (Federal Information Processing Standards) 140-2 is a U.S. government standard for cryptographic modules. FIPS mode restricts cryptographic operations to only those approved by the standard, which is required for some government and regulated industry projects.

### FIPS Mode in This Project
- By default, FIPS mode is **not enabled**. You may see log messages like:
  `[ssl:debug] ... OpenSSL has FIPS mode disabled`
- This is expected unless you have a compliance requirement.

### Enabling FIPS Mode
- If your project requires FIPS 140-2 compliance, you must:
  1. Use FIPS-capable base images for Apache and OpenSSL.
  2. Build or obtain FIPS-enabled versions of OpenSSL and Apache.
  3. Enable FIPS mode via configuration or environment variables.
- This is not included in the default setup and requires advanced configuration.

### References
- [OpenSSL FIPS User Guide](https://www.openssl.org/docs/fips/UserGuide-2.0.pdf)
- [Apache mod_ssl FIPS Notes](https://httpd.apache.org/docs/2.4/mod/mod_ssl.html#fips)