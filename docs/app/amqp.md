# 总览 | Overview

 **写于 2023-12-31 兔年的最后一天**
!!! info "引言"
    本篇文章将会涉及到对应用层协议AMQP(Advanced Message Queuing Protocols)以及消息队列rabbitMQ的介绍，本文旨在串联起网络相关的知识点，对于在介绍AMQP过程中涉及到的其他计算机网络相关的技术原理，只会进行比较浅显的介绍

    1. AMQP是一种用于客户端程序之间相互通信的应用层协议,它为C/S架构的通信实体的行为制定了抽象的需要遵守的规范，它是一种可编程的协议，提供给了应用开发者一部分自由，具体的实现细节例如实体间的通信路由交给开发者自行设计
    2. RabbitMQ是使用Erlang编程语言开发的一款消息队列应用,具体实现了AMQP 0-9-1 协议
    [rabbitMQ官方文档](https://www.rabbitmq.com/tutorials/amqp-concepts.html#highlevel-overview)

## 认识RabbitMQ

RabbitMQ架构图
![架构](img/amqp1.png)

???+ key-point "① 接口与实现"
    AMQP相当于接口，RabbitMQ完全实现了AMQP的要求，所以它是AMQP的一种实现形式，因此可以在任何AMQP预设的场景下使用。但是这不是充要条件，如果一个实现可以充当消息队列，并不说明它实现了AMQP，例如kafka

    AMQP 0-9-1 规定了通信消息传递的规范：

    1. 消息实体：
          - 产生者(Publisher/Producer)
          - 交换机(Exchanger)
          - 队列（Queue）
          - 消费者（Consumer）
    2. 行为：

           - 消息传输使用TCP确保可靠，使用TLS确保安全
           - 使用Channle处理多连接，节省资源消耗
           - 使用Vhost实现环境隔离，由客户端选择使用哪个Vhost

    RabbitMQ 实现的方法：

    - 与AMQP服务器连接的建立与关闭（Connection）
    - 利用多路复用技术建立进程/线程隔离轻量化连接（Channel）
    - 声明交换机和队列
    - 交换机对消息进行路由
    - 为队列绑定键
    - 消息持久化和确认


???+ section "② 应用关键词解释"

    1. Broker：一个消息队列服务提供方
    2. vhost：一个Broker中互不干扰的多个消息队列实例
    3. Connection：使用者与服务器建立的TCP连接，可以复用
        - 连接形式amqp://userName:password@ipAddress:portNumber/virtualHost
    4. Channel：专用连接，可以在一个Connection中无限创建；大部分实际功能都在Channel中
    5. Exchange：根据规则分发消息进入Queue的模型
        - Name：交换机名称
        - Type：交换机类型
            - "" ：空字符串是一个默认的Direct模式Exchange
            - Direct：向绑定的 Name == RoutingKey 的队列发送
            - Fanout：向绑定的队列全体广播
            - Topic：向绑定的 Name 模式匹配 RoutingKey 的队列发送
            - routingKey 可以是 *.logger.# 这种表达式
                - \* 代表一个词
                - \# 代表0或多个词
            - Header：不常用，根据Message Header进行任意或全部键值对匹配
        - Durability：持久化标志，表明此交换机是否是持久化的
        - Auto-delete：删除标志，表明当所有队列在完成使用此exchange时，是否删除
        - Arguments：其它参数
    6. Queue：保存消息的队列结构，需要与Exchange绑定（Bind）
       - Name：队列名称
        - Durable：消息代理重启后，队列依旧存在
        - Exclusive：只被一个连接（connection）使用，而且当连接关闭后队列即被删除
        - Auto-delete：当最后一个消费者退订后即被删除
        - Arguments：其它参数
    7. Message：一条消息
        - ExchangeName：指定发送到的Exchange
        - Header：一个Map，存储元数据（用于Header Exchange）
        - RoutingKey：指定消息的Tag
        - ContentType：数据类型标记
        - Data：二进制数据

???+ section "③ 使用流程，以golang SDK举例"

    演示流程仅供参考，实际生产环境的消费队列使用请查阅相关资料
    演示程序泳道图
    ![流程演示](img/amqp2.png)

    建立连接（客户端，服务端步骤相同）
    ```golang
        conn,_:=amqp.Dial(amqp://userName:password@ipAddress:portNumber/virtualHost)
        channle,_:=conn.Channel()
    ```

    生产端
    ```golang
        //声明并设置Exchanger的属性，具体可参考上一段落关键词描述
        channel.ExchangerDeclare(Attributes...)

        /* Publish 发送消息
        * exchangerName 交换机名称
        * routingKey 用于消息路由的key，最终会与队列的bindingKey比对确认消息的接收队列
        * messagerWrapper 消息的载体，除了消息本身还提供了Broker代理消息的一些选项信息
        */
        channel.Publish(exchangerName,routingKey,messageWrapper)
    ```

    服务端
    ```golang
        //声明并设置Queue的属性，具体可参考上一段落关键词描述
        queue,err:=channel.QueueDeclare(Attributes...)

        /* QueueBind 将Queue与对应的Exchanger绑定，并且设置bindingKey用于消息的路由
        * queueName 队列名字
        * bindingKey 绑定键
        * exchangerName 交换机名称
        * options 与声明队列时设置的一些属性相同
        */
        channel.QueueBind(queueName,bindingKey,exchangerName,options...)

        //接收消息 获取一个可以持续接收消息的通道
        msgChannel , _ :=channel.Consume(queueName,consumerID,options...)

        //服务端自定义业务逻辑处理消息

    ```

???+ section "④ RabbitMQ与Erlang"

    RabbitMQ的核心部分使用erlang语言编写，现在这是一门冷门的语言，但是这门语言并不普通 ( 详情请查阅[官方文档](https://www.erlang.org/) )。

    Erlang的语言哲学从设计之初就包含了高并发的思想，采用了轻量化的多进程模型（尽管当时的硬件并不能支持高并发），同时它也是一门函数式编程的语言，在正常的代码开发中也会涉及到大量的递归调用，这些都加大了学习的难度，另外erlang应用的开发是基于OTP思想，同现在流行的面向对象(OOP)思想又有些差异，这需要学习者能够改变固有思维

    综上，解读RabbitMQ源码的难度不小，并且实现涉及到的知识面会非常广，在拓宽眼界的同时需要抓住重点。
