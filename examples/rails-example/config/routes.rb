ActionController::Routing::Routes.draw do |map|
  map.resources :products, :member => { :buy => :get, :purchase => :post, :confirmation => :get }
  map.root :controller => :products
end
