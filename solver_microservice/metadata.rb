# frozen_string_literal: true

name             'solver_microservice'
maintainer       'SDTechDev Dev Team'
maintainer_email 'dev@jiffyshirts.com'
license          'Proprietary - All Rights Reserved'
description      'runs python solver microservice on the rails app server'
version          '0.0.1'

depends 'application_python'
depends 'poise-python'
depends 'poise-application'

recipe 'solver_microservice::setup', 'Sync and start python solver'
