# frozen-string-literal: true

Dir[File.join(File.dirname(__FILE__), '.', 'jiratk', '**.rb')].sort.each do |f|
  require f
end
