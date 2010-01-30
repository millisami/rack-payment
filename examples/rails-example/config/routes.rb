ActionController::Routing::Routes.draw do |map|
  map.resources :products, :member => { :buy => :get }
  map.root :controller => :products
end
