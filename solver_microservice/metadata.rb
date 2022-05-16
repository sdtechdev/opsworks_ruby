# frozen_string_literal: true

name             'solver_microservice'
maintainer       'SDTechDev Dev Team'
maintainer_email 'dev@jiffyshirts.com'
license          'Proprietary - All Rights Reserved'
description      'runs python solver microservice on the rails app server'
version          '0.0.1'

depends 'pyenv', '~> 1.0'

recipe 'solver_microservice::setup', 'Sync and start python solver'
