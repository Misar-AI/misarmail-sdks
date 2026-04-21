require_relative "misar_mail/errors"
require_relative "misar_mail/client"

module MisarMail
  def self.new(**kwargs)
    Client.new(**kwargs)
  end
end
