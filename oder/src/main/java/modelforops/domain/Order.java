package modelforops.domain;

import java.util.Date;
import java.util.List;
import javax.persistence.*;
import lombok.Data;
import modelforops.OderApplication;
import modelforops.domain.OrderPlaced;

@Entity
@Table(name = "Order_table")
@Data
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;
    private Long productId;    
    private String productName;
    private Integer qty;
    private String status;

    @PostPersist
    public void onPostPersist() {
        OrderPlaced orderPlaced = new OrderPlaced(this);
        orderPlaced.publishAfterCommit();
    }

    public static OrderRepository repository() {
        OrderRepository orderRepository = OderApplication.applicationContext.getBean(
            OrderRepository.class
        );
        return orderRepository;
    }
}
