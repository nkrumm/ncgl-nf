@Grab('io.github.http-builder-ng:http-builder-ng-core:1.0.4')
import groovy.json.JsonSlurper
import groovy.json.JsonOutput

import static groovyx.net.http.HttpBuilder.configure
import static groovyx.net.http.ContentTypes.JSON
import groovyx.net.http.*
import static groovy.json.JsonOutput.prettyPrint

class PodUtils {
    static getPodGenes(pod_code){

        def result = configure {
            request.uri = 'https://ncgl.uwcpdx.org'
            request.contentType = 'application/transit+json'
            request.encoder('application/transit+json'){ ChainedHttpConfig config, ToServer req->
                req.toServer(new ByteArrayInputStream(
                    "${config.request.body}".bytes
                ))
            }
        }.post {
            request.uri.path = '/backend/anon/pull'
            request.body = '["^ ","~:idref",["~:panel.adhoc/hashid","' + pod_code + '"],"~:pattern",[["^ ","~:panel/genes",["~:gene/approved-symbol","~:gene/approved-name","~:gene/locus-type","~:gene/coverage"]]]]'
        }
        return result
    }
}