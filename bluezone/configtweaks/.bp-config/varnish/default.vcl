/*-
 * Copyright (c) 2006 Verdens Gang AS
 * Copyright (c) 2006-2011 Varnish Software AS
 * All rights reserved.
 *
 * Author: Poul-Henning Kamp <phk@phk.freebsd.dk>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The default VCL code.
 *
 * NB! You do NOT need to copy & paste all of these functions into your
 * own vcl code, if you do not provide a definition of one of these
 * functions, the compiler will automatically fall back to the default
 * code from this file.
 *
 * This code will be prefixed with a backend declaration built from the
 * -b argument.
 */

/***
 * Include Authcache Varnish core.vcl
 */

include "authcache_core.vcl";

backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .first_byte_timeout     = 300s;   # How long to wait before we receive a first byte from our backend?
    .connect_timeout        = 10s;     # How long to wait for a backend connection?
    .between_bytes_timeout  = 10s;     # How long to wait between bytes received from our backend?
}

/*
 * Not really necessary for Cloud Foundry ... but objects needs to be defined for later if statements.
 */
acl internal {
  # "192.10.0.0"/24;
  #  For remote access, add your IP address here.
  #  Ex: 162.xxx.xx.xx
}

/**
 * Defines where the authcache varnish key callback is located.
 *
 * Note that the key-retrieval path must start with a slash and must include
 * the path prefix if any (e.g. on multilingual sites or if Drupal is installed
 * in a subdirectory).
 */
sub authcache_key_path {
  set req.http.X-Authcache-Key-Path = "/authcache-varnish-get-key";

  // Example of a multilingual site relying on path prefixes.
  # set req.http.X-Authcache-Key-Path = "/en/authcache-varnish-get-key";

  // Example of a drupal instance installed in a subdirectory.
  # set req.http.X-Authcache-Key-Path = "/drupal/authcache-varnish-get-key";
}

/**
 * Derive the cache identifier for the key cache.
 */
sub authcache_key_cid {
  if (req.http.Cookie ~ "(^|;)\s*S?SESS[a-z0-9]+=") {
    // Use the whole session cookie to differentiate between authenticated
    // users.
    set req.http.X-Authcache-Key-CID = "sess:"+regsuball(req.http.Cookie, "^(.*;\s*)?(S?SESS[a-z0-9]+=[^;]*).*$", "\2");
  }
  else {
    // If authcache key retrieval was enforced for anonymous traffic, the HTTP
    // host is used in order to keep apart anonymous users of different
    // domains.
    set req.http.X-Authcache-Key-CID = "host:"+req.http.host;
  }

  /* Optional: When using authcache_esi alongside with authcache_ajax */
   if (req.http.Cookie ~ "(^|;)\s*has_js=1\s*($|;)") {
     set req.http.X-Authcache-Key-CID = req.http.X-Authcache-Key-CID + "+js";
   }
   else {
     set req.http.X-Authcache-Key-CID = req.http.X-Authcache-Key-CID + "-js";
   }

  /* Optional: When serving HTTP/HTTPS */
   if (req.http.X-Forwarded-Proto ~ "(?i)https") {
     set req.http.X-Authcache-Key-CID = req.http.X-Authcache-Key-CID + "+ssl";
   }
   else {
     set req.http.X-Authcache-Key-CID = req.http.X-Authcache-Key-CID + "-ssl";
   }
}

/**
 * Place your custom vcl_recv code here.
 */
sub authcache_recv {
  # Use anonymous, cached pages if all backends are down.
  if (!req.backend.healthy) {
    unset req.http.Cookie;
  }
 
  # Allow the backend to serve up stale content if it is responding slowly.
  set req.grace = 6h;
 
  # Pipe these paths directly to Apache for streaming.
  if (req.url ~ "^/admin/content/backup_migrate/export") {
    return (pipe);
  }
 
  if (req.restarts == 0) {
    if (req.http.x-forwarded-for) {
      set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
    }
    else {
      set req.http.X-Forwarded-For = client.ip;
    }
  }
  
  # Do not allow outside access to cron.php or install.php.
  if (req.url ~ "^/(cron|install)\.php$" && !client.ip ~ internal) {
    # Have Varnish throw the error directly.
    error 404 "Page not found.";
    # Use a custom error page that you've defined in Drupal at the path "404".
    set req.url = "/404";
  }
 
 
  # Always cache the following file types for all users. This list of extensions
  # appears twice, once here and again in vcl_fetch so make sure you edit both
  # and keep them equal.
  if (req.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
    unset req.http.Cookie;
  }
 
  # Remove all cookies that Drupal doesn't need to know about. We explicitly
  # list the ones that Drupal does need, the SESS and NO_CACHE. If, after
  # running this code we find that either of these two cookies remains, we
  # will pass as the page cannot be cached.
   if (req.http.Cookie) {
    # 1. Append a semi-colon to the front of the cookie string.
    # 2. Remove all spaces that appear after semi-colons.
    # 3. Match the cookies we want to keep, adding the space we removed
    #    previously back. (\1) is first matching group in the regsuball.
    # 4. Remove all other cookies, identifying them by the fact that they have
    #    no space after the preceding semi-colon.
    # 5. Remove all spaces and semi-colons from the beginning and end of the
    #    cookie string.
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");   
    set req.http.Cookie = regsuball(req.http.Cookie, ";(SESS[a-z0-9]+|SSESS[a-z0-9]+|NO_CACHE)=", "; \1=");
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
 
   	if (req.http.Cookie == "") {
      # If there are no remaining cookies, remove the cookie header. If there
      # aren't any cookie headers, Varnish's default behavior will be to cache
      # the page.
      unset req.http.Cookie;
   	}
   }
  
  // TODO: Add purge handler, access checks and other stuff relying on
  // non-standard HTTP verbs here.

  // /**
  //  * Example 1: Allow purge from all clients in the purge-acl. Note that
  //  * additional VCL is necessary to make this work, notably the acl and some
  //  * code in vcl_miss and vcl_hit.
  //  *
  //  * More information on:
  //  * https://www.varnish-cache.org/docs/3.0/tutorial/purging.html
  //  */
  // if (req.method == "PURGE") {
  //   if (!client.ip ~ purge) {
  //     error 405 "Not allowed.";
  //   }
  //   return (lookup);
  // }

  // /**
  //  * Example 2: Do not allow outside access to cron.php or install.php.
  //  */
  // if (req.url ~ "^/(cron|install)\.php$" && !client.ip ~ internal) {
  //   error 404 "Page not found.";
  // }

  // TODO: Place your custom *pass*-rules here. Do *not* introduce any lookups.

  // /* Example 1: Never cache admin/cron/user pages. */
  if (
  		req.url ~ "^/admin$" ||
  		req.url ~ "^/admin/.*$" ||
       	req.url ~ "^/batch.*$" ||
       	req.url ~ "^/comment/edit.*$" ||
       	req.url ~ "^/cron\.php$" ||
        req.url ~ "^/file/ajax/.*" ||
        req.url ~ "^/install\.php$" ||
        req.url ~ "^/node/*/edit$" ||
        req.url ~ "^/node/*/track$" ||
        req.url ~ "^/node/add/.*$" ||
        req.url ~ "^/status\.php$" ||
        req.url ~ "^/system/files/*.$" ||
        req.url ~ "^/system/temporary.*$" ||
        req.url ~ "^/update\.php$" ||
        req.url ~ "^/tracker$" ||
        req.url ~ "^/update\.php$" ||
        req.url ~ "^/user$" ||
        req.url ~ "^/user/.*$" ||
        req.url ~ "^/users/.*$"
    ) {
      		return (pass);
  	  }

  // /**
  //  * Example 2: Remove all but
  //  * - the session cookie (SESSxxx, SSESSxxx)
  //  * - the cache invalidation cookie for authcache p13n (aucp13n)
  //  * - the NO_CACHE cookie from the Bypass Advanced module
  //  * - the nocache cookie from authcache
  //  *
  //  * Note: Please also add the has_js cookie to the list if Authcache Ajax
  //  * is also enabled in the backend. Also if you have Authcache Debug enabled,
  //  * you should let through the aucdbg cookie.
  //  *
  //  * More information on:
  //  * https://www.varnish-cache.org/docs/3.0/tutorial/cookies.html
  //  */
  // if (req.http.Cookie) {
  //   set req.http.Cookie = ";" + req.http.Cookie;
  //   set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
  //   set req.http.Cookie = regsuball(req.http.Cookie, ";(S?SESS[a-z0-9]+|aucp13n|NO_CACHE|nocache)=", "; \1=");
  //   set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
  //   set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

  //   if (req.http.Cookie == "") {
  //     unset req.http.Cookie;
  //   }
  // }

  // /**
  //  * Example 3: Only attempt authcache key retrieval for the domain
  //  * example.com and skip it for all other domains.
  //  *
  //  * Note: When key retrieval is forcibly prevented, the default VCL rules
  //  * will kick in. I.e. only requests having no cookies at all will be
  //  * cacheable.
  //  */
  // if (req.http.host != "example.com" && req.http.host != "www.example.com") {
  //   set req.http.X-Authcache-Get-Key = "skip";
  // }

  // /**
  //  * Example 4: Trigger key-retrieval for all users, including anonymous.
  //  *
  //  * Forcing key-retrieval for users without a session enables caching even for
  //  * requests with cookies. This is required in any of the following situations:
  //  * - If pages delivered to anonymous users contain Authcache ESI fragments.
  //  * - A custom key generator is in place for anonymous users. E.g. to separate
  //  *   cache bins according to language / region / device type.
  //  * - The Authcache Debug widget is enabled for all users (including anonymous).
  //  */
  
  if (!req.http.X-Authcache-Get-Key) {
    set req.http.X-Authcache-Get-Key = "get";
  }
}

# VCL_DELIVER 
# Set a header to track a cache HIT/MISS.
sub vcl_deliver {
  if (obj.hits > 0) {
    set resp.http.X-Varnish-Cache = "HIT";
  }
  else {
    set resp.http.X-Varnish-Cache = "MISS";
  }
}

# VCL_FETCH 
# Code determining what to do when serving items from the Apache servers.
# beresp == Back-end response from the web server.
sub vcl_fetch {
  
  # We need this to cache 404s, 301s, 500s. Otherwise, depending on backend but
  # definitely in Drupal's case these responses are not cacheable by default.
  if (beresp.status == 404 || beresp.status == 301 || beresp.status == 500) {
    set beresp.ttl = 10m;
  }
 
  # Don't allow static files to set cookies.
  # (?i) denotes case insensitive in PCRE (perl compatible regular expressions).
  # This list of extensions appears twice, once here and again in vcl_recv so
  # make sure you edit both and keep them equal.
  if (req.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
    unset beresp.http.set-cookie;
  }
  
  # Compress content before storing it in cache. Compress text, js, css, and web fonts.
  if (beresp.http.content-type ~ "(text|application/javascript|text/css|application/x-font-ttf|application/x-font-opentype|application/vnd.ms-fontobject)") {
    set beresp.do_gzip = true;
  }
 
  # Allow items to be stale if needed.
  set beresp.grace = 6h;
  
  # Varnish determined the object was not cacheable
  if (beresp.ttl <= 0s) {
    set beresp.http.X-Cacheable = "NO:Not Cacheable";

  # You don't wish to cache content for logged in users
  } elsif (req.http.Cookie ~ "(UserID|_session)") {
    set beresp.http.X-Cacheable = "NO:Got Session";
    return(hit_for_pass);  

  # You are respecting the Cache-Control=private header from the backend
  } elsif (beresp.http.Cache-Control ~ "private") {
    set beresp.http.X-Cacheable = "NO:Cache-Control=private";
    return(hit_for_pass);
    
  # Varnish determined the object was cacheable
  } else {  
    set beresp.http.X-Cacheable = "YES";
  }
  
  return(deliver);
}
 
# In the event of an error, show friendlier messages.
# VCL_ERROR
sub vcl_error {
  # Redirect to some other URL in the case of a homepage failure.
  #if (req.url ~ "^/?$") {
  #  set obj.status = 302;
  #  set obj.http.Location = "http://backup.example.com/";
  #}
 
  # Otherwise redirect to the homepage, which will likely be in the cache.
  set obj.http.Content-Type = "text/html; charset=utf-8";
  synthetic {"
<html>
<head>
  <title>Page Unavailable</title>
  <style>
    body { background: #303030; text-align: center; color: white; }
    #page { border: 1px solid #CCC; width: 500px; margin: 100px auto 0; padding: 30px; background: #323232; }
    a, a:link, a:visited { color: #CCC; }
    .error { color: #222; }
  </style>
</head>
<body onload="setTimeout(function() { window.location = '/' }, 5000)">
  <div id="page">
    <h1 class="title">Page Unavailable</h1>
    <p>The page you requested is temporarily unavailable.</p>
    <p>We're redirecting you to the <a href="/">homepage</a> in 5 seconds.</p>
    <div class="error">(Error "} + obj.status + " " + obj.response + {")</div>
  </div>
</body>
</html>
"};
  return (deliver);
}

# VCL_HASH
sub vcl_hash {
  if (req.http.Cookie) {
    hash_data(req.http.Cookie);
  }
  
  if (req.http.x-forwarded-proto) {
    hash_data(req.http.x-forwarded-proto);
  }
}
