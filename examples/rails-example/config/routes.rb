ActionController::Routing::Routes.draw do |map|
  map.resources :products, :member => { :buy => [:get, :post] }
  map.root :controller => :products
end
