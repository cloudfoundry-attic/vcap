# Python Support

Python applications are supported through the WSGI protocol. Gunicorn is used as
the web server serving WSGI applications, including Django. Non-Django
applications must have a top-level ``wsgi.py`` exposing an ``application``
variable that points to a WSGI application.

## Installing dependencies using pip

Python package prerequisites of your application can be defined in a top-level
``requirements.txt`` file (see [format
documentation](http://www.pip-installer.org/en/latest/requirement-format.html)),
which file is used by pip to install dependencies.

### Limitations

* Package dependencies are never cached, and they will be downloaded (and
  installed) every time your app is updated or restarted.

## Django support

A special framework called "Django" exists to also perform Django-specific
staging actions. At the moment, this runs `syncdb` non-interactively to
initialize the database.

### Accessing the database

Cloud Foundry makes the service connection credentials available as JSON via the
`VCAP_SERVICES` environment variable. Using this knowledge, you can use the
following snippet in your own settings.py:

    ## Pull in CloudFoundry's production settings
    if 'VCAP_SERVICES' in os.environ:
        import json
        vcap_services = json.loads(os.environ['VCAP_SERVICES'])
        # XXX: avoid hardcoding here
        mysql_srv = vcap_services['mysql-5.1'][0]
        cred = mysql_srv['credentials']
        DATABASES = {
            'default': {
                'ENGINE': 'django.db.backends.mysql',
                'NAME': cred['name'],
                'USER': cred['user'],
                'PASSWORD': cred['password'],
                'HOST': cred['hostname'],
                'PORT': cred['port'],
                }
            }
    else:
        DATABASES = {
            "default": {
                "ENGINE": "django.db.backends.sqlite3",
                "NAME": "dev.db",
                "USER": "",
                "PASSWORD": "",
                "HOST": "",
                "PORT": "",
                }
            }

### Limitations

* Django admin (if your app uses it) will be unusable as superusers are not
  created due to running `syncdb` non-interactively.

* Migration workflow, such as that of [South](http://south.aeracode.org/) are
  not supported.

