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

### Limitations

* Django admin (if your app uses it) will be unusable as superusers are not
  created due to running `syncdb` non-interactively.

* Migration workflow, such as that of [South](http://south.aeracode.org/) are
  not supported.

## Sample applications

### A hello world WSGI application

Here's a sample WSGI application using the "bottle" web framework.

    $ mkdir myapp && cd myapp
    $ cat > wsgi.py
    import os
    import sys
    import bottle

    @bottle.route('/')
    def index():
        pyver = '.'.join(map(str, tuple(sys.version_info)[:3]))
        return 'Hello World! (from <b>Python %s</b>)' % (pyver,)

    application = bottle.default_app()

    if __name__ == '__main__':
        bottle.run(host='localhost', port=8000)

    $ cat > requirements.txt
    bottle
    $
