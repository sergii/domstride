# Transitional public entrypoint. Keep a single implementation and class identity.
require_relative "domstride"
SpecDrive = Domstride unless defined?(SpecDrive)
