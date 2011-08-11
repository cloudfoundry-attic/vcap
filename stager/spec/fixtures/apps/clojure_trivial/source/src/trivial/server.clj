(ns trivial.server
  (:require [noir.server :as server])
  (:use noir.core
        hiccup.core))

(defpage "/" []
  (html [:p "Trivial!"]))

(defn -main [& m]
  (let [mode (keyword (or (first m) :dev))
        port (Integer. (get (System/getenv) "PORT" "8080"))]
    (server/start port {:mode mode
                        :ns 'trivial})))

