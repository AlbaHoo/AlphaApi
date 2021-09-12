require 'fast_jsonapi'

module AlphaApi
  class ApplicationRecordSerializer
    include FastJsonapi::ObjectSerializer

    class << self
      def requested?(name)
        ->(_record, params) { params && params[:included]&.include?(name.to_s) }
      end
    end
  end
end
